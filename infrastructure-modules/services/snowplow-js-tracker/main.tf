terraform {
  required_version = "~> 0.12.18"

  required_providers {
    aws = "~> 2.43.0"
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "static_content" {
  acl           = "private"
  bucket        = var.bucket
  force_destroy = false
  region        = "eu-west-1"
  request_payer = "BucketOwner"
  tags          = var.tags

  versioning {
    enabled    = false
    mfa_delete = false
  }
}



resource "aws_s3_bucket_policy" "static_content" {
  bucket = aws_s3_bucket.static_content.bucket
  policy = jsonencode(
    {
      Id = "PolicyForCloudFrontPrivateContent"
      Statement = [
        {
          Action = "s3:GetObject"
          Effect = "Allow"
          Principal = {
            AWS = aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn
          }
          Resource = "${aws_s3_bucket.static_content.arn}/*"
          Sid      = "1"
        },
      ]
      Version = "2008-10-17"
    }
  )
}

resource "aws_cloudfront_distribution" "cdn" {
  aliases             = []
  enabled             = true
  http_version        = "http2"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  tags                = {}
  wait_for_deployment = true

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]
    cached_methods = [
      "GET",
      "HEAD",
    ]
    compress               = true
    default_ttl            = 86400
    max_ttl                = 31536000
    min_ttl                = 0
    smooth_streaming       = false
    target_origin_id       = "S3-${aws_s3_bucket.static_content.bucket}"
    trusted_signers        = []
    viewer_protocol_policy = "allow-all"

    forwarded_values {
      headers                 = []
      query_string            = false
      query_string_cache_keys = []

      cookies {
        forward           = "none"
        whitelisted_names = []
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.static_content.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.static_content.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${aws_s3_bucket.static_content.bucket_regional_domain_name}"
}

