local logger = require("srclink.Logger")

logger.enableLogging()
logger.log("Test succeeded!")

print(logger.dumpLogs())