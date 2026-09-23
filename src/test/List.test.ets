import localUnitTest from './LocalUnit.test';
import metadataTest from './Metadata.test';
import ddlTest from './Ddl.test';

export default function testsuite() {
  localUnitTest();
  metadataTest();
  ddlTest();
}
