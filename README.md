KyVote application for voting using Dex tech


Some requirements:

1. Every one can create a campaign for other people to vote. Each campaign includes:
  - title - purpose of the campaign)
  - options (list of options to vote)
  - optionCount (number of options, as using mapping for list of options in the campaign)
  - end (time to end the campaign, admin/creator of the campaign can stop the campaign at any time)
  - creatorID (ID of the campaign creator, for example: telegram id)
  - admin (address of creator, only this address can edit the campaign)
  - isMultipleChoices (allow to vote multiple options or not)

2. Creator can set the end time when creating the campaign, but can stop the campaign at end time as well, other data can not be modified after created

3. Option is unique for each campaign by its id. The id is counted from 0. Option includes:
  - id (id of the option, only need to be unique for each campaign)
  - name (name of the option)
  - url (could be image link, or link to more details of the option)
  - voterIDs (list of IDs of voters that have voted for this option)

3. User can vote for one or list of options by providing their chosen options and campaign ID

4. User can unvote or revote

Should be able to call:
  - create a campaign with valid data
  - stop a campaign if the creator wanted
  - get list of campaigns, and list of active campaigns
  - check if a campaign is active using its id
  - get campaign details
  - get number of options for a campaign
  - get list details of options for a campaign
  - get an option given its id and its campaign id
  - get list of voterIDs given campaign and option id (optional as can get from api above, but this will reduce redundant data to return as (name, url, id) currently can not be changed)
  
  More requirements could be added as feedbacks from others.
  
