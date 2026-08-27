-- Auto Generated (Do not modify) 29F281807648D2DDB64113ED85A68D7AF272B9878F77FF06BFC7C5D7DCFF37B6
CREATE   
	VIEW Export.vw_SharepointData 

AS
/*
Date		Name			Change Description
---------------------------------------------------------------------
2026/01/27	Mazhar			Lift and shift from DW with 
							EDW related changes/updates applied 
							(data is ingested using powerautomate by 
							the SharePoint team)

USAGE
SELECT * FROM Export.[vw_SharepointData] WHERE Crederian = 'Matthew Maguire'
*/

--select * from kimble.History_CapabilityType

SELECT 
	 Crederian
	,Grade
	,IsFeeEarning
	,CrederanStartDate
	,CrederanEndDate
	,ResourceType
	,EmailAddress
	,ResourceBu
	,InternalAlignment
	,Competencies
	,Account
	,CurerntClientAssignment
	,LatestCurrentAssignmentEndDate
	,InternalRoles
	,Certifications
	,Propositions
	,CareerCoach
	,Summary
	,ResourceURL
	,AccountURL
  FROM Export.SharepointData