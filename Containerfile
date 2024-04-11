ARG DRIVER_TOOLKIT_IMAGE=''

FROM ${DRIVER_TOOLKIT_IMAGE} as builder

ARG RHEL_VERSION=''
ARG KERNEL_VERSION=''

ARG BUILD_ARCH=''
ARG TARGET_ARCH=''

ARG DRIVER_VERSION=''

ARG BUILDER_USER=''
ARG BUILDER_EMAIL=''

USER builder

WORKDIR /home/builder

RUN echo "KERNEL_VERSION=${KERNEL_VERSION}"

RUN RHEL_VERSION_MAJOR=$(echo "${RHEL_VERSION}" | cut -d '.' -f 1) \
    && mkdir -p /home/builder/habanalabs \
    && cd /home/builder/habanalabs \
    && curl -sLO https://vault.habana.ai/artifactory/rhel/${RHEL_VERSION_MAJOR}/9.2/habanalabs-${DRIVER_VERSION}.el${RHEL_VERSION_MAJOR}.noarch.rpm \
    && curl -sLO https://vault.habana.ai/artifactory/rhel/${RHEL_VERSION_MAJOR}/9.2/habanalabs-firmware-${DRIVER_VERSION}.el${RHEL_VERSION_MAJOR}.${TARGET_ARCH}.rpm \
    && rpm2cpio habanalabs-${DRIVER_VERSION}.el${RHEL_VERSION_MAJOR}.noarch.rpm | cpio -id \
    && rpm2cpio habanalabs-firmware-${DRIVER_VERSION}.el${RHEL_VERSION_MAJOR}.${TARGET_ARCH}.rpm | cpio -id \
    && cd ./usr/src/habanalabs-${DRIVER_VERSION} \
    && make -j$(nproc) KVERSION=${KERNEL_VERSION} GIT_SHA=$(cat dkms.conf | grep "KMD_LAST_GIT_SHA=" | cut -d "=" -f 2) \
    && xz drivers/accel/habanalabs/habanalabs.ko

FROM registry.redhat.io/rhel9-beta/rhel-bootc:9.4

ARG KERNEL_VERSION=''

ARG DRIVER_VERSION=''

USER root

COPY --from=builder --chown=0:0 /home/builder/habanalabs/usr/src/habanalabs-${DRIVER_VERSION}/drivers/accel/habanalabs/habanalabs.ko.xz /lib/modules/${KERNEL_VERSION}/extra/habanalabs.ko.xz
COPY --from=builder --chown=0:0 /home/builder/habanalabs/lib/firmware/habanalabs/gaudi /lib/firmware/habanalabs/gaudi

RUN depmod -a ${KERNEL_VERSION}

# Setup /usr/lib/containers/storage as an additional store for images.
# Remove once the base images have this set by default.
RUN sed -i -e '/additionalimage.*/a "/usr/lib/containers/storage",' \
    	/etc/containers/storage.conf \
    && mkdir -p /usr/lib/containers/storage

# Added for running as an OCI Container to prevent Overlay on Overlay issues.
VOLUME /var/lib/containers

LABEL io.k8s.display-name="Image-based RHEL with Intel Gaudi driver"
LABEL name="Image-based RHEL with Intel Gaudi driver"
LABEL vendor="${BUILDER_USER}"
LABEL version="${RHEL_VERSION}-${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision image-based RHEL system with Intel Gaudi driver"
LABEL description="Provision image-based RHEL system with Intel Gaudi driver"

CMD ["/usr/bin/bash"]
