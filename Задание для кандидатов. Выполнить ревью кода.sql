create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as
set nocount on
begin
	-- 16. Все переменные задаются в одном объявлении
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
	-- 1. Рекомендуется при объявлении типов не использовать длину поля max
	,@ErrorMessage varchar(max)

	-- Проверка на корректность загрузки
	if not exists (
	-- 2. В условных операторах с одним условием весь блок с условиями смещается на один отступ
		select 1
	-- 3. При наименовании алиаса использовать первые заглавные буквы каждого слова в названии объекта, которому дают алиас.
		from syn.ImportFile as imf
		where imf.ID = @ID_Record
			and imf.FlagLoaded = cast(1 as bit)
	)
		begin
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'

			raiserror(@ErrorMessage, 3, 1)
			-- 10. нужна пустая строка перед return
	
			return
		end

	-- 12. Логический отступ, создание таблицы
	CREATE TABLE #ProcessedRows (
		ActionType varchar(255),
		ID int
	)

	-- 4. Пробел перед текстом комментария
	-- Чтение из слоя временных данных
	-- 5. При create table запятые остаются в конце строк, чтоб не менять код при автоматической генерации
	select
		-- 14. Не обязательно указывать схему в ID_dbo_Customer, так как схема та же
		cc.ID as ID_Customer
		/* 
		11. Объекты состоят в разных схемах, 
		поэтому должно быть другое название поля [ID_][схема_]{Название}[_Постфикс] 
		*/
		,cst.ID as ID_syn_CustomerSystemType
		,s.ID as ID_Season
		,cast(cs.DateBegin as date) as DateBegin
		,cast(cs.DateEnd as date) as DateEnd
		-- 13. Схема одна, поэтому dbo в названии не нужно
		,cd.ID as ID_CustomerDistributor
		,cast(isnull(cs.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal
	-- 15. Не хватает as
	from syn.SA_CustomerSeasonal as cs
		join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = cs.Season
		join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		join syn.CustomerSystemType as cst on cs.CustomerSystemType = cst.Name
	where try_cast(cs.DateBegin as date) is not null
		and try_cast(cs.DateEnd as date) is not null
		and try_cast(isnull(cs.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной	
	select
		-- 6. Перечисление атрибутов с новой строки
		cs.*
		,case
			-- 7. Результат на 1 отступ от when, с новой строки
			when cc.ID is null 
				then 'UID клиента отсутствует в справочнике "Клиент"'
			when cd.ID is null 
				then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null 
				then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null 
				then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(cs.DateBegin as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(cs.DateEnd as date) is null 
				then 'Невозможно определить Дату начала'
			when try_cast(isnull(cs.FlagActive, 0) as bit) is null 
				then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
		-- 8. 1 отступ при join 
		left join dbo.Customer as cc on cc.UID_DS = cs.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
	-- 9. Условие and с новой строки, 2 отступа
		left join dbo.Customer as cd on cd.UID_DS = cs.UID_DS_CustomerDistributor 
			and cd.ID_mapping_DataSource = 1
		left join dbo.Season as s on s.Name = cs.Season
		left join syn.CustomerSystemType as cst on cst.Name = cs.CustomerSystemType
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(cs.DateBegin as date) is null
		or try_cast(cs.DateEnd as date) is null
		or try_cast(isnull(cs.FlagActive, 0) as bit) is null
		
end
