"""
Structured JSON logging configuration for Titanic API
"""
import json
import logging
import os
from datetime import datetime
from typing import Any, Dict


class JSONFormatter(logging.Formatter):
    """
    Custom JSON formatter for structured logging
    """
    
    def format(self, record: logging.LogRecord) -> str:
        """
        Format log record as JSON
        
        Parameters:
            record: Log record to format
            
        Returns:
            JSON string representation of log record
        """
        log_data: Dict[str, Any] = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": os.getenv("SERVICE_NAME", "titanic-api"),
            "environment": os.getenv("FLASK_ENV", "development"),
        }
        
        if hasattr(record, "request_id"):
            log_data["request_id"] = record.request_id
            
        if hasattr(record, "user_id"):
            log_data["user_id"] = record.user_id
            
        if hasattr(record, "path"):
            log_data["path"] = record.path
            
        if hasattr(record, "method"):
            log_data["method"] = record.method
            
        if hasattr(record, "status_code"):
            log_data["status_code"] = record.status_code
            
        if hasattr(record, "duration_ms"):
            log_data["duration_ms"] = record.duration_ms
        
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
            
        if record.stack_info:
            log_data["stack"] = self.formatStack(record.stack_info)
        
        return json.dumps(log_data)


def setup_logging(log_level: str = "INFO") -> None:
    """
    Configure structured JSON logging
    
    Parameters:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    """
    handler = logging.StreamHandler()
    handler.setFormatter(JSONFormatter())
    
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))
    root_logger.addHandler(handler)
    
    for logger_name in ["werkzeug", "gunicorn", "sqlalchemy"]:
        logger = logging.getLogger(logger_name)
        logger.setLevel(logging.WARNING)
        logger.addHandler(handler)
