codeunit 70101 "Smoke S1 Test"
{
    Subtype = Test;

    [Test]
    procedure TestGreeting()
    var
        Hello: Codeunit "Smoke S1 Hello";
    begin
        // Simple assertion that the procedure returns non-empty text
        if Hello.GetGreeting() = '' then
            Error('Greeting should not be empty');
    end;
}
