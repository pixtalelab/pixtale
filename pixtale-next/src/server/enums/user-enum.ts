// 这个模块定义用户相关枚举值。

const UserStatusEnum = {
  DEFAULT: 0,
  NORMAL: 1,
  DISABLE: 2
} as const;

const UserTypeEnum = {
  ADMIN: 1,
  NORMAL: 2,
  DEMO: 3
} as const;

const UserTypeOptions = [
  { label: "普通用户", value: UserTypeEnum.NORMAL },
  { label: "管理员", value: UserTypeEnum.ADMIN },
  { label: "演示用户", value: UserTypeEnum.DEMO }
];

export { UserStatusEnum, UserTypeEnum, UserTypeOptions };
