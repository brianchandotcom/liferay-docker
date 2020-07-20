#!/bin/bash

PROJECTS="\
    apps/dynamic-data-mapping/dynamic-data-mapping-demo-data-creator-api\
    apps/dynamic-data-mapping/dynamic-data-mapping-demo-data-creator-impl\
    apps/portal-workflow/portal-workflow-kaleo-demo-data-creator-api\
    apps/portal-workflow/portal-workflow-kaleo-demo-data-creator-impl\
    apps/users-admin/users-admin-demo-data-creator-api\
    apps/users-admin/users-admin-demo-data-creator-impl\
    dxp/apps/portal-workflow/portal-workflow-metrics-demo\
    dxp/apps/portal-workflow/portal-workflow-metrics-demo-data-creator-api\
    dxp/apps/portal-workflow/portal-workflow-metrics-demo-data-creator-impl"

for PROJECT in $PROJECTS; do
    curl -O "$(wget -q -O- https://raw.githubusercontent.com/liferay/liferay-portal/$TAG/modules/.releng/$PROJECT/artifact.properties | sed -n 's/artifact.url=//p')"
done