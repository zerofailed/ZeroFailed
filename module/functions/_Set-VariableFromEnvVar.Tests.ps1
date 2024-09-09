$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

function resetEnvVars {
    # Ensure the special environment variables used for testing purposes are reset between tests
    # We can't use 'BeforeEach' ir 'AfterEach' as they run before each 'It' block which would wipe
    # the environment variables too soon.
    $env:_SetVariableFromEnvVarValue = ""
    $env:_SetVariableFromEnvVarTypeName = ""
}

Describe "Set-VariableFromEnvVar Tests" {

    Context "String values" {

        Describe "When overriding an existing variable" {

            resetEnvVars
            $script:someString = "foo"
            $env:newValueForSomeString = "bar"
            $res = Set-VariableFromEnvVar -VariableName "someString" -EnvironmentVariableName "newValueForSomeString" -TestMode

            It "should return true" {
                $res | Should -Be $true
            }
            It "should treat the variable as a string" {
                $env:_SetVariableFromEnvVarTypeName | Should -Be "String"
            }
            It "should update the variable with the correct value" {
                $env:_SetVariableFromEnvVarValue | Should -Be "bar"
            }
        }

        Describe "When overriding an existing variable that is null" {

            resetEnvVars
            $script:nullVar = $null
            $env:newValueForNullVar = "foo"
            $res = Set-VariableFromEnvVar -VariableName "nullVar" -EnvironmentVariableName "newValueForNullVar" -TestMode

            It "should return true" {
                $res | Should -Be $true
            }
            It "should treat the variable as a string" {
                $env:_SetVariableFromEnvVarTypeName | Should -Be "String"
            }
            It "should update the variable with the correct value" {
                $env:_SetVariableFromEnvVarValue | Should -Be "foo"
            }
        }
    }

    Context "Integer values" {

        Describe "When overriding an existing variable" {

            resetEnvVars
            $script:someNum = 1
            $env:newValueForsomeNum = "5"
            $res = Set-VariableFromEnvVar -VariableName "someNum" -EnvironmentVariableName "newValueForsomeNum" -TestMode

            It "should return true" {
                $res | Should -Be $true
            }
            It "should treat the variable as an integer" {
                $env:_SetVariableFromEnvVarTypeName | Should -Be "Int32"
            }
            It "should update the variable with the correct value" {
                $env:_SetVariableFromEnvVarValue | Should -Be 5
            }
        }
    }

    Context "Boolean values" {

        Describe "When overriding an existing variable" {

            resetEnvVars
            $script:someFlag = $false
            $env:newValueForSomeFlag = "True"
            $res = Set-VariableFromEnvVar -VariableName "someFlag" -EnvironmentVariableName "newValueForSomeFlag" -TestMode

            It "should return true" {
                $res | Should -Be $true
            }
            It "should treat the variable as a boolean" {
                $env:_SetVariableFromEnvVarTypeName | Should -Be "Boolean"
            }
            It "should update the variable with the correct value" {
                $env:_SetVariableFromEnvVarValue | Should -Be $true
            }
        }
    }

    Context "Hashtable values" {

        Describe "When overriding an existing variable with a valid JSON object" {

            resetEnvVars
            $script:someDictionary = @{foo="bar"; bar="foo"}
            $env:newValueForsomeDictionary = '{"foo": "foo", "bar": "bar"}'
            $res = Set-VariableFromEnvVar -VariableName "someDictionary" -EnvironmentVariableName "newValueForsomeDictionary" -TestMode

            It "should return true" {
                $res | Should -Be $true
            }
            It "should treat the variable as a hashtable" {
                $env:_SetVariableFromEnvVarTypeName | Should -BeIn @("Hashtable", "OrderedHashtable")
                $env:_SetVariableFromEnvVarValue | ConvertFrom-Json -AsHashtable | Should -BeOfType [Hashtable] 
            }
            It "should update the variable with the correct value" {
                $roundtrippedActual = $env:_SetVariableFromEnvVarValue | ConvertFrom-Json -AsHashtable
                $roundtrippedActual["foo"] | Should -Be "foo"
                $roundtrippedActual["bar"] | Should -Be "bar"
            }
        }

        Describe "When overriding an existing variable with invalid JSON" {

            Mock Write-Warning {}

            resetEnvVars
            $script:someDictionary = @{foo="bar"; bar="foo"}
            $env:newValueForsomeDictionary = '{"foo"="foo", "bar"="bar"}'
            $res = Set-VariableFromEnvVar -VariableName "someDictionary" -EnvironmentVariableName "newValueForsomeDictionary" -TestMode

            It "should return false" {
                $res | Should -Be $false
            }
            It "should log a warning" {
                Assert-MockCalled Write-Warning -Times 1
            }
            It "should not update the variable with the correct value" {
                $env:_SetVariableFromEnvVarTypeName | Should -BeNullOrEmpty
                $env:_SetVariableFromEnvVarValue | Should -BeNullOrEmpty
            }
        }
    }

    Context "Array values" {

        Describe "When overriding an existing array variable with a valid JSON object" {

            resetEnvVars
            $script:someArray = @("foo", "bar")
            $env:newValueForSomeArray = '["bar", "foo"]'
            $res = Set-VariableFromEnvVar -VariableName "someArray" -EnvironmentVariableName "newValueForSomeArray" -TestMode

            It "should return true" {
                $res | Should -Be $true
            }
            It "should treat the variable as an array" {
                $env:_SetVariableFromEnvVarTypeName | Should -Be "Object[]"
                # Using -BeOfType results in comparing with the type of the first array element rather than the array itself
                ($env:_SetVariableFromEnvVarValue | ConvertFrom-Json -AsHashtable).GetType().Name | Should -Be "Object[]"
            }
            It "should update the variable with the correct value" {
                $env:_SetVariableFromEnvVarValue | ConvertFrom-Json -AsHashtable | Should -Be @("bar", "foo")
            }
        }

        Describe "When overriding an empty array variable with a valid JSON object" {

            resetEnvVars
            $script:someArray = @()
            $env:newValueForSomeArray = '["foobar", "barfoo"]'
            $res = Set-VariableFromEnvVar -VariableName "someArray" -EnvironmentVariableName "newValueForSomeArray" -TestMode

            It "should return true" {
                $res | Should -Be $true
            }
            It "should treat the variable as an array" {
                $env:_SetVariableFromEnvVarTypeName | Should -Be "Object[]"
                # Using -BeOfType results in comparing with the type of the first array element rather than the array itself
                ($env:_SetVariableFromEnvVarValue | ConvertFrom-Json -AsHashtable).GetType().Name | Should -Be "Object[]"
            }
            It "should update the variable with the correct value" {
                $env:_SetVariableFromEnvVarValue | ConvertFrom-Json -AsHashtable | Should -Be @("foobar", "barfoo")
            }
        }

        Describe "When overriding an existing array variable with invalid JSON" {

            Mock Write-Warning {}

            resetEnvVars
            $script:someArray =  @("foo", "bar")
            $env:newValueForsomeArray = '[ bar, foo ]'
            $res = Set-VariableFromEnvVar -VariableName "someArray" -EnvironmentVariableName "newValueForsomeArray" -TestMode

            It "should return false" {
                $res | Should -Be $false
            }
            It "should log a warning" {
                Assert-MockCalled Write-Warning -Times 1
            }
            It "should not update the variable with the correct value" {
                $env:_SetVariableFromEnvVarTypeName | Should -BeNullOrEmpty
                $env:_SetVariableFromEnvVarValue | Should -BeNullOrEmpty
            }
        }
    }
}
