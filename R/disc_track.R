#' Manually track a larva
#'
#' Use the manual tracking plugin to record a track
#'
#' @param dir deployment directory
#' @param sub subsampling interval, in s
#' @param verbose output messages on the console when TRUE
#'
#' @export
disc_track <- function(dir, sub=NULL, verbose=FALSE, ...) {

  disc_message("Track")

  # checks
  picsDir <- make_path(dir, .files$pictures)
  assert_that(file.exists(picsDir))

  picsFile <- make_path(dir, str_c(.files$pictures, ".csv"))
  assert_that(file.exists(picsFile))

  pics <- list.files(picsDir, pattern=glob2rx("*.jpg"))
  assert_that(not_empty(pics))


  # Determine sub-sampling rate, if any
  # compute interval between images
  picsData <- read.csv(picsFile)
  interval <- mean(as.numeric(diff(picsData$dateTime)))

  # compute the subsampling rate
  if ( is.null(sub) ) {
    subN <- 1
  } else {
    subN <- round(sub / interval)
    # one image every subN will give an interval of sub seconds, approximately
    if (verbose) {
      disc_message("subsample at ", round(subN * interval, 2), " seconds, on average")
    }
  }

	# Determine whether to use a virtual stack or a real one
	# nb of images opened = total / subsampling rate
	nbOpened <- length(pics) / subN
	# when there are less than 30 frames to open, loading them is fast and not too memory hungry
	# in that case, use a regular stack, other wise use a virtual stack
	if ( nbOpened <= 30 ) {
	  virtualStack <- ""
	} else {
	  virtualStack <- "use"
	}

	if (verbose) disc_message("open stack for tracking")
  # prepare temporary storage
  larvaTracksFile <- tempfile(fileext="txt")

	# Use an ImageJ macro to run everything. The macro proceeds this way
	# - use Image Sequence to open the stack
	# - call the Manual Tracking plugin
	# - use waitForUser to let the time for the user to track larvae
	# - save the tracks to an appropriate file
	# - quit
  command <- str_c(
    "java -Xmx", getOption("disc.java_memory"), "m -jar ", system.file("ij/ij.jar", package="discuss"),
    " -ijpath ", system.file("ij/", package="discuss"), " -eval \"",
    " run('Image Sequence...', 'open=", picsDir, " number=0 starting=1 increment=", subN, " scale=100 file=[] or=[] sort ", virtualStack,"');",
    # " run('Manual Tracking', '');",
    " run('Compile and Run...', 'compile=", system.file("ij/", package="discuss"),"/plugins/Manual_Tracking.java');",
    " waitForUser('Track finished?',",
    " 'Press OK when done tracking');",
    " selectWindow('Tracks');",
    " saveAs('Text', '", larvaTracksFile, "');",
    " run('Quit');\""
  )
  status <- system(command)
  check_status(status, message=str_c("Error running command\n:", command, "\nAbort"))

  # save larva track
  assert_that(file.exists(larvaTracksFile))
  destFile <- make_path(dir, .files$tracks)
  if ( verbose ) disc_message("write track to ", destFile)
  d <- read.delim(larvaTracksFile, row.names=1)
  write.csv(d, file=destFile, row.names=FALSE)
  file.remove(larvaTracksFile)

  return(invisible(status))
}