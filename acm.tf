# Request the ACM certificate
resource "aws_acm_certificate" "web_cert" {
  domain_name       = "www3.${data.aws_route53_zone.styrinov.name}"
  validation_method = "DNS"

  tags = {
    Name = "Web ALB Cert"
  }
}