FROM registry.access.redhat.com/ubi7/ubi-minimal:7.7-303

ARG VCS_REF
ARG VCS_URL
ARG IMAGE_NAME
ARG IMAGE_DESCRIPTION
ARG SUMMARY
ARG GOARCH

RUN microdnf update && \
      microdnf install shadow-utils procps && \
      groupadd -r controller && adduser -rm -g controller -u 100 controller && \
      microdnf clean all

ADD iam-policy_$GOARCH /usr/bin/iam-policy-controller

RUN chmod a+x /usr/bin/iam-policy-controller

RUN mkdir /licenses

COPY packages.yaml /licenses

USER controller

ENTRYPOINT ["/usr/bin/iam-policy-controller"]

# http://label-schema.org/rc1/
LABEL org.label-schema.vendor="IBM" \
      org.label-schema.name="$IMAGE_NAME" \
      org.label-schema.description="$IMAGE_DESCRIPTION" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.license="Licensed Materials - Property of IBM" \
      org.label-schema.schema-version="1.0"

LABEL name="$IMAGE_NAME"
LABEL vendor="IBM"
LABEL version="1.0"
LABEL release="$VCS_REF"
LABEL summary="$SUMMARY"
LABEL description="$IMAGE_DESCRIPTION"
