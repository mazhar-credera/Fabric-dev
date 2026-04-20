CREATE --OR ALTER
	FUNCTION dbo.CurrencyLookup
()
RETURNS TABLE
WITH SCHEMABINDING 
AS
RETURN 

			SELECT CurrencyIsoCode, CurrencyName, CurrencyCountry
			FROM	
				(VALUES	
					('AUD' , 'Australian Dollar' , 'AUSTRALIA') , 
					('AED' , 'Emirati Dirham' , 'UNITED ARAB EMIRATES') , 
					('CAD' , 'Canadian Dollar' , 'CANADA') , 
					('CHF' , 'Swiss Franc' , 'SWITZERLAND') , 
					('DKK' , 'Danish Krone' , 'DENMARK') , 
					('EUR' , 'Euro' , 'EU') , 
					('GBP' , 'Pound Sterling' , 'UNITED KINGDOM OF GREAT BRITAIN AND NORTHERN IRELAND (THE)') , 
					('NOK' , 'Norwegian Krone' , 'NORWAY') , 
					('NZD' , 'New Zealand Dollar' , 'NEW ZEALAND') , 
					('SEK' , 'Swedish Krona' , 'SWEDEN') , 
					('USD' , 'US Dollar' , 'UNITED STATES OF AMERICA (THE)') 
				)	AS T(	CurrencyIsoCode, CurrencyName, CurrencyCountry	) 
			;