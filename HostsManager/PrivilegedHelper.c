#include "PrivilegedHelper.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>

static AuthorizationRef cachedAuthRef = NULL;

OSStatus acquireAuthorization(void) {
    if (cachedAuthRef != NULL) {
        return errAuthorizationSuccess;
    }

    AuthorizationItem authItem = {
        .name = kAuthorizationRightExecute,
        .valueLength = 0,
        .value = NULL,
        .flags = 0
    };
    AuthorizationRights authRights = {
        .count = 1,
        .items = &authItem
    };

    AuthorizationFlags flags =
        kAuthorizationFlagInteractionAllowed |
        kAuthorizationFlagPreAuthorize |
        kAuthorizationFlagExtendRights;

    OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &cachedAuthRef);
    if (status != errAuthorizationSuccess) {
        cachedAuthRef = NULL;
    }
    return status;
}

OSStatus runPrivilegedShellCommand(const char *command) {
    // Acquire authorization if not cached
    OSStatus status = acquireAuthorization();
    if (status != errAuthorizationSuccess) {
        return status;
    }

    char *args[] = { "-c", (char *)command, NULL };
    FILE *outputFile = NULL;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    status = AuthorizationExecuteWithPrivileges(cachedAuthRef, "/bin/sh", kAuthorizationFlagDefaults, args, &outputFile);
#pragma clang diagnostic pop

    if (status == errAuthorizationSuccess && outputFile != NULL) {
        char buf[4096];
        while (fgets(buf, sizeof(buf), outputFile) != NULL) {}
        fclose(outputFile);

        int childStatus;
        wait(&childStatus);
    }

    // If authorization expired or was revoked, clear cache so next call re-prompts
    if (status == errAuthorizationCanceled || status == errAuthorizationDenied) {
        AuthorizationFree(cachedAuthRef, kAuthorizationFlagDefaults);
        cachedAuthRef = NULL;
    }

    return status;
}

void releaseAuthorization(void) {
    if (cachedAuthRef != NULL) {
        AuthorizationFree(cachedAuthRef, kAuthorizationFlagDefaults);
        cachedAuthRef = NULL;
    }
}
