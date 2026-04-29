CREATE --OR ALTER 
	PROCEDURE dbo.usp_Update_DimVendorPostingGroup
	--Default Parameters
	@ExecutionId	INT , 
	@Watermark		VARCHAR(255) , 
	@ProcessId		INT 
 
AS
BEGIN
	SET NOCOUNT ON;
	/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	SCD1
	USAGE 
	SELECT * FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendorPostingGroup]'
	DECLARE @ProcessId INT = (SELECT ProcessId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendorPostingGroup]')
	DECLARE @LastExecId INT = (SELECT LastExecutionId FROM FabricDb.ETL.ProcessMap WHERE ProcessPath = '[dbo].[usp_Update_DimVendorPostingGroup]')
	EXEC dbo.usp_Update_DimVendorPostingGroup @ExecutionId = @LastExecId, @Watermark ='20000101', @ProcessId=@ProcessId ;
	SELECT * FROM [dbo].[DimVendorPostingGroup] ; 
	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
	--Default Parameters 
	DECLARE @_ExecutionId	INT = @ExecutionId, 
			--@_Watermark		DATETIME2 = CAST(@Watermark AS DATETIME2) ,
			@_Watermark		DATETIME2 = '20000101', /*groundhog day*/
			@_ProcessId		INT = @ProcessId; 

	DECLARE @strNewWatermark	VARCHAR(35) ,
			@strOldWatermark	VARCHAR(35) = CONVERT(VARCHAR(35),@_Watermark,121);

	BEGIN TRY

		BEGIN TRANSACTION 

			DROP TABLE IF EXISTS #Source ;

			TRUNCATE TABLE dbo.DimVendorPostingGroup ; 

			INSERT INTO dbo.DimVendorPostingGroup ( 
				VendorPostingGroupSk, VendorPostingGroupName, BcCompanySk, [Description], PayablesAccount
						,_crda_CreatedExecutionId, _crda_CreatedDateTime 
			) 
			SELECT	VendorPostingGroupSk, VendorPostingGroupName, BcCompanySk, [Description], PayablesAccount
						,_crda_CreatedExecutionId, _crda_CreatedDateTime
			FROM	(VALUES	(	
					-1 , 'UnknownRecord' , -1, '', '' 
						, @_ExecutionId, GETUTCDATE()  ) 
					)	AS T(	VendorPostingGroupSk, VendorPostingGroupName, BcCompanySk , [Description], PayablesAccount
									 ,_crda_CreatedExecutionId, _crda_CreatedDateTime
			) 
			WHERE NOT EXISTS ( 
				SELECT	1 
				FROM	dbo.DimVendorPostingGroup B 
				WHERE	B.VendorPostingGroupSk	= T.VendorPostingGroupSk 
			) ; 


			SELECT
				BcCompanySk	= ISNULL(BC.BcCompanySk, -1) ,
				VendorPostingGroupName = B.Code ,
				B.[Description] ,
				B.PayablesAccount , 
				B._crda_ActiveFromDateTime 

			INTO #Source
			FROM	lh_SilverLayer.BC.HISTORY_VendorPostingGroup	B 
			LEFT JOIN dbo.DimBcCompany				BC	ON	BC.BC_CompanyName = B.BC_CompanyName 

			WHERE	B._crda_ActiveFromDateTime	> @_Watermark  
			AND		B._crda_isDeleted			= 0  
			AND		B._crda_ActiveToDateTime	= '9999-12-31 23:59:59' 
			GROUP BY
				ISNULL(BC.BcCompanySk, -1) ,
				B.Code , 
				B.[Description] , 
				B.PayablesAccount 
				,AD._crda_Hash 
			ORDER BY 
				ISNULL(BC.BcCompanySk, -1) ,
				B.Code ; 


			INSERT INTO	dbo.DimVendorPostingGroup 
			( 
				 VendorPostingGroupSk 
				,BcCompanySk
				,VendorPostingGroupName
				,[Description]
				,PayablesAccount

				,_crda_CreatedExecutionId
				,_crda_CreatedDateTime
			)
			SELECT 
				 ROW_NUMBER()OVER (ORDER BY VendorPostingGroupName, BcCompanySk) 
				,SRC.BcCompanySk
				,SRC.VendorPostingGroupName 
				,SRC.[Description]
				,SRC.PayablesAccount

				,@_ExecutionId 
				,GETUTCDATE() 
			FROM		#Source SRC 
			ORDER BY VendorPostingGroupName, BcCompanySk ; 


			SELECT @strNewWatermark = CONVERT(VARCHAR(35),ISNULL(MAX(S._crda_ActiveFromDateTime), @_Watermark),121) FROM #Source S ;


			SELECT	InitialWatermark	= @strOldWatermark, 
					UpdatedWatermark	= @strNewWatermark ; 

		COMMIT;

	END TRY
	BEGIN CATCH
		ROLLBACK;
		THROW;
	END CATCH ; 

	IF @@TRANCOUNT > 0 ROLLBACK; 

END;