import abilityTest from './Ability.test';
import crudTest from './Crud.test';
import relationTest from './Relation.test';
import migrationTest from './Migration.test';

export default function testsuite() {
  abilityTest();
  crudTest();
  relationTest();
  migrationTest();
}
