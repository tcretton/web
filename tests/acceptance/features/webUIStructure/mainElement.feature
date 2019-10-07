Feature: Main Element exists
  As a user of an assistive technology
  I want to navigate via landmarks
  So that I can quickly reach the webapp's main content area

  Scenario: Checking if a main landmark exists
    When the user has browsed to the files page
    Then they will find only one main element
