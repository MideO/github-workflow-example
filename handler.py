import aws_lambda_logging
import logging.config


logging.config.fileConfig("logging.conf", disable_existing_loggers=False)
aws_lambda_logging.setup(level="INFO")
log = logging.getLogger("handler")


def handle(event, context):
    log.info(f"incoming event {event}")
    return "Hello World"
