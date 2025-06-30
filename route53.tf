
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.styrinov.zone_id
  name    = "${var.subdomain}.${var.my_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.main.public_ip]
}

resource "aws_route53_record" "bastion_dns" {
  count   = var.ver.env == "dev" ? 1 : 0
  zone_id = data.aws_route53_zone.styrinov.zone_id

  name    = "bastion.${var.ver.env}.${var.my_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.bastion_eip[0].public_ip]
}

resource "aws_route53_record" "www3" {
  zone_id = data.aws_route53_zone.styrinov.zone_id
  name    = "www3.${data.aws_route53_zone.styrinov.name}"
  type    = "A"

  alias {
    name                   = module.web_alb.alb_dns_name
    zone_id                = module.web_alb.alb_zone_id
    evaluate_target_health = true
  }
}


# Create the DNS validation record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.web_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.styrinov.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Validation resource to complete the issuance
resource "aws_acm_certificate_validation" "web_cert_validation" {
  certificate_arn         = aws_acm_certificate.web_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

