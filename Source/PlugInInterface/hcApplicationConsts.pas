unit hcApplicationConsts;

interface

const
  //registry keys and value names
  STR_ComponentSuffix = 'Component';
  STR_CompanyName = 'HCI';   // Place your company name here.
  STR_ApplicationName = 'CompositeApp';
  STR_ApplicationVersionNumber = '1.0';

  REG_ApplicationRegistryPath = 'Software\' + STR_CompanyName + '\' + STR_ApplicationName+'\'+STR_ApplicationVersionNumber;


implementation

end.
