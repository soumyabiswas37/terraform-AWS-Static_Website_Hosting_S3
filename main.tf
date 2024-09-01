provider "aws" {
    region = var.region
}

resource "aws_s3_bucket" "my_new_bucket" {
    bucket = var.bucket_name
    tags = {
        Name = var.bucket_tag
        Environment = "${terraform.workspace}"
    }
    object_lock_enabled = true
}

resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
    bucket = aws_s3_bucket.my_new_bucket.id
    rule {
        object_ownership = var.object_owner
    }
    depends_on = [ aws_s3_bucket.my_new_bucket ]
}

resource "aws_s3_bucket_public_access_block" "public_access_rules" {
    bucket = aws_s3_bucket.my_new_bucket.id
    block_public_acls = false
    block_public_policy = false
    ignore_public_acls = false
    restrict_public_buckets = false
    depends_on = [ 
        aws_s3_bucket_ownership_controls.bucket_ownership,
        aws_s3_bucket.my_new_bucket
        ]
}

resource "aws_s3_bucket_acl" "bucket_acl" {
    bucket = aws_s3_bucket.my_new_bucket.id
    acl = var.access_control
    depends_on = [ 
        aws_s3_bucket.my_new_bucket,
        aws_s3_bucket_ownership_controls.bucket_ownership,
        aws_s3_bucket_public_access_block.public_access_rules
        ]
}

resource "aws_s3_bucket_versioning" "bucket_version" {
    bucket = aws_s3_bucket.my_new_bucket.id
    versioning_configuration {
        status = "Enabled"
    }
    depends_on = [ 
        aws_s3_bucket.my_new_bucket,
        aws_s3_bucket_acl.bucket_acl,
        aws_s3_bucket_ownership_controls.bucket_ownership,
        aws_s3_bucket_public_access_block.public_access_rules
        ]
}

resource "aws_s3_object" "new_object1" {
    key = var.index
    bucket = aws_s3_bucket.my_new_bucket.id
    acl = var.access_control
    source = var.index
    content_type = var.content_type
       depends_on = [ 
        aws_s3_bucket_versioning.bucket_version
        ]
}

resource "aws_s3_object" "new_object2" {
    key = var.error
    bucket = aws_s3_bucket.my_new_bucket.id
    acl = var.access_control
    source = var.error
    content_type = var.content_type
    depends_on = [ aws_s3_bucket_versioning.bucket_version ]
}

resource "aws_s3_bucket_website_configuration" "new_configure1" {
    bucket = aws_s3_bucket.my_new_bucket.id
    index_document {
      suffix = var.index
    }
    error_document {
      key = var.error
    }
    depends_on = [ 
        aws_s3_object.new_object2,
        aws_s3_object.new_object1
     ]
}

resource "null_resource" "null1" {
  provisioner "local-exec" {
    command = "start http://${aws_s3_bucket_website_configuration.new_configure1.website_endpoint}/${var.index}"
  }
  depends_on = [ aws_s3_bucket_website_configuration.new_configure1 ]
}

output "Bucket_ID" {
    value = aws_s3_bucket.my_new_bucket.id
}

output "website_endpoint" {
    value = aws_s3_bucket_website_configuration.new_configure1.website_endpoint
}