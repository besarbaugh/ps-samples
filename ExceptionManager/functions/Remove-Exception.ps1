GroupCollectionPage result = graphServiceClient.groups()
    .buildRequest(requestOptions)
    .get();

if (result == null || result.getCurrentPage() == null || result.getCurrentPage().isEmpty()) {
    LOGGER.error("No group data found for the query.");
    return;
}

String groupId = result.getCurrentPage().get(0).id;
LOGGER.info("Group ID: " + groupId);
