# crood-build-system
# bitbucket-pipelines.yml
          # python image with aws-cli installed
          image: atlassian/pipelines-awscli
          script:
            - apk add --update curl curl-dev openssl && rm -rf /var/cache/apk/*
            - curl -fsSL -o buildscript.sh https://github.com/AlindHere/crood-build-system/raw/main/croodbuild.sh
            - bash -v buildscript.sh
