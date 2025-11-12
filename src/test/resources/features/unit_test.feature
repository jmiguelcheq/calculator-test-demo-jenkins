@UNIT
Feature: Calculator unit operations
  Scenario Outline: Perform basic math: (<operation>)
    Given two numbers <firstNumber> and <secondNumber>
    When I <operation> them
    Then the result should be <expected>
    Examples:
      | firstNumber | secondNumber | operation | expected |
      | 2  		    | 3  		   | add       | 5        |
      | 10 		    | 4  		   | subtract  | 6        |
      | 7  		    | 6  		   | multiply  | 42       |
      | 10 			| 5  		   | divide    | 2        |
