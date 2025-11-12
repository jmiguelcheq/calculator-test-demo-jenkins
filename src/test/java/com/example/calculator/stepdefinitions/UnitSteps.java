package com.example.calculator.stepdefinitions;

import io.cucumber.java.en.*;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

import com.example.calculator.pages.LandingPage;
import com.example.calculator_manager.DriverManager;
import org.openqa.selenium.*;

/**
 * Cucumber steps that perform operations using the actual
 * web calculator at https://jmiguelcheq.github.io/calculator-demo
 */
public class UnitSteps {

	WebDriver driver;
    private LandingPage landingPage;
    
    public UnitSteps() {
        this.driver = DriverManager.getDriver();
        this.landingPage = new LandingPage(driver);
    }

    @Given("two numbers {double} and {double}")
    public void nums(double firstNumber, double secondNumber) {
    	landingPage.inputNumberOne(String.valueOf(firstNumber));
    	landingPage.inputNumberTwo(String.valueOf(secondNumber));
    }

    @When("I {word} them")
    public void performOperation(String operation) {
    	landingPage.selectOperation(operation);
    	landingPage.clickCompute();
    }

    @Then("the result should be {double}")
    public void verify(double expected) {
      assertThat(landingPage.getResult()).as("Verify calculator result equals expected").isCloseTo(expected, within(0.001));
    }
}
