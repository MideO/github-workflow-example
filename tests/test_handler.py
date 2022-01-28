import handler


def test_handler():
    # Given
    event = {'some': 'event'}
    context = None

    # When
    actual = handler.handle(event, context)

    # THen
    assert actual == 'Hello World'
