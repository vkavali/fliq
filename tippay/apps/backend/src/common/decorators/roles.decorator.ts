import { SetMetadata } from '@nestjs/common';
import { UserType } from '@tippay/shared';

export const ROLES_KEY = 'roles';

/**
 * Restricts access to users with the specified roles.
 * Usage: @Roles(UserType.ADMIN)
 */
export const Roles = (...roles: UserType[]) => SetMetadata(ROLES_KEY, roles);
