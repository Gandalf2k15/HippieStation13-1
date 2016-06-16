
/client/verb/admin_ticket(ticket_title as text)
	set category = "Admin"
	set name = "Adminhelp"

	if(prefs.muted & MUTE_ADMINHELP)
		src << "<font color='red'>Error: Admin-PM: You are unable to use admin PM-s (muted).</font>"
		return

	if(!ticket_title)
		usr << "<span class='ticket-status'>You did not supply a message for your Adminhelp. Ignoring your request.</span>"
		return

	ticket_title = replacetext(ticket_title, "'", "\'")
	ticket_title = sanitize(copytext(ticket_title,1,MAX_MESSAGE_LEN))

	var/datum/admin_ticket/found_ticket = null
	for(var/datum/admin_ticket/T in tickets_list)
		if(compare_ckey(T.owner_ckey, src) && !T.resolved)
			found_ticket = T

	if(!found_ticket)
		var/datum/admin_ticket/T = new /datum/admin_ticket(src, ticket_title)

		if(!T.error)
			tickets_list.Add(T)
		else
			T = null
	else
		found_ticket.owner = src
		if(!compare_ckey(src, found_ticket.owner))
			found_ticket.owner << output("[gameTimestamp()] - <b>[key_name(found_ticket.owner, 1)]</b> - [ticket_title]", "ViewTicketLog[found_ticket.ticket_id].browser:add_message")
		found_ticket.add_log(ticket_title)

/client/verb/view_my_ticket()
	set category = "Admin"
	set name = "View My Adminhelps"
	// Firstly, check if we are the owner of a ticket. This should be our first priority.
	var/hasticket = 0
	for(var/datum/admin_ticket/T in tickets_list)
		if(compare_ckey(T.owner_ckey, usr))
			T.view_log()
			hasticket = 1
		//return
	// If we reach here, perhaps we have a ticket to handle. That should be shown.
	for(var/datum/admin_ticket/T in tickets_list)
		if(compare_ckey(T.handling_admin, usr))
			T.view_log()
			hasticket = 1
		//return
	if(hasticket == 0)
		usr << "<span class='ticket-status'>Oops! You do not appear to have a Adminhelp!</span>"
	else
		hasticket = 0
		return

/client/proc/view_tickets()
	set category = "Admin"
	set name = "Adminlisttickets"

	view_tickets_main(TICKET_FLAG_LIST_ALL)

/client/proc/view_tickets_main(var/flag)
	flag = text2num(flag)
	if(!flag)
		flag = TICKET_FLAG_LIST_ALL

	var/content = ""

	if(holder)
		content += {"<p class='info-bar'>
			<a href='?user=\ref[src];action=refresh_admin_ticket_list;flag=[flag]'>Refresh List</a>
			<a href='?user=\ref[src];action=refresh_admin_ticket_list;flag=[(flag | TICKET_FLAG_LIST_ALL) & ~TICKET_FLAG_LIST_MINE & ~TICKET_FLAG_LIST_UNCLAIMED]'>All Adminhelps</a>

			<a href='?user=\ref[src];action=refresh_admin_ticket_list;flag=
				[flag & TICKET_FLAG_LIST_MINE ? "[(flag & ~TICKET_FLAG_LIST_MINE) & ~TICKET_FLAG_LIST_ALL]" : "[(flag | TICKET_FLAG_LIST_MINE) & ~TICKET_FLAG_LIST_ALL]"]
				'>[flag & TICKET_FLAG_LIST_MINE ? "� " : ""]My Adminhelps</a>

			<a href='?user=\ref[src];action=refresh_admin_ticket_list;flag=
				[flag & TICKET_FLAG_LIST_UNCLAIMED ? "[(flag & ~TICKET_FLAG_LIST_UNCLAIMED) & ~TICKET_FLAG_LIST_ALL]" : "[(flag | TICKET_FLAG_LIST_UNCLAIMED) & ~TICKET_FLAG_LIST_ALL]"]
				'>[flag & TICKET_FLAG_LIST_UNCLAIMED ? "� " : ""]Unclaimed</a>

		</p>"}

		content += {"<p class='info-bar'>
			Filtering:<b>
			[(flag & TICKET_FLAG_LIST_ALL) ? " All" : ""]
			[(flag & TICKET_FLAG_LIST_MINE) ? " Mine" : ""]
			[(flag & TICKET_FLAG_LIST_UNCLAIMED) ? " Unclaimed" : ""]
		</b></p>"}

		var/list/resolved = new /list()
		var/list/unresolved = new /list()

		for(var/i = tickets_list.len, i >= 1, i--)
			var/datum/admin_ticket/T = tickets_list[i]

			var/include = 0

			if(!(flag & TICKET_FLAG_LIST_ALL))
				if(flag & TICKET_FLAG_LIST_MINE)
					if(!compare_ckey(src, T.owner_ckey) && !compare_ckey(src, T.handling_admin))
						include = 0
					else
						include = 1

				if(!include && flag & TICKET_FLAG_LIST_UNCLAIMED)
					if(T.handling_admin)
						include = 0
					else
						include = 1
			else
				include = 1

			if(!include)
				continue

			if(T.resolved)
				resolved.Add(T)
			else
				unresolved.Add(T)

		if(unresolved.len == 0 && resolved.len == 0)
			content += "<p class='info-bar emboldened'>There are no Adminhelps matching your filter(s)</p>"

		if(unresolved.len > 0)
			content += "<p class='info-bar unresolved emboldened large-font'>Unresolved Adminhelps ([unresolved.len]/[tickets_list.len]):</p>"
			for(var/datum/admin_ticket/T in unresolved)
				if(!T.owner)
					content += {"<p class='ticket-bar'>
						<span class='ticket-number'>#[T.ticket_id]</span>
						<b>[T.handling_admin ? "" : "<span class='unclaimed'>Unclaimed</span>!"] [T.title]</b><br />
						<b>Owner:</b> <b>[T.owner_ckey] (DC)</b>
						<a href='?src=\ref[T];user=\ref[src];action=view_admin_ticket;ticket=\ref[T]'><img border='0' width='16' height='16' class='uiIcon16 icon-search' /> View</a>
						<a href='?src=\ref[T];user=\ref[src];action=monitor_admin_ticket;ticket=\ref[T];reloadlist=1' class='monitor-button'><img border='0' width='16' height='16' class='uiIcon16 icon-pin-s' /> <span>[!T.is_monitor(usr.client) ? "Un" : ""]Monitor</span></a>
						<a href='?src=\ref[T];user=\ref[src];action=resolve_admin_ticket;ticket=\ref[T];reloadlist=1' class='resolve-button'><img border='0' width='16' height='16' class='uiIcon16 icon-check' /> <span>[T.resolved ? "Un" : ""]Resolve</span></a>
						</p>"}
				else
					var/ai_found = (T.owner && isAI(get_ckey(T.owner)))
					content += {"<p class='ticket-bar'>
						<span class='ticket-number'>#[T.ticket_id]</span>
						<b>[T.handling_admin ? "" : "<span class='unclaimed'>Unclaimed</span>"] [T.title]</b><br />
						<b>Owner:</b> <b>[key_name(T.owner, 1)]</b><br />
						[T.handling_admin ? " <b>Admin:</b> [T.handling_admin]<br />" : ""]
						<a href='?src=\ref[T];user=\ref[src];action=view_admin_ticket;ticket=\ref[T]'><img border='0' width='16' height='16' class='uiIcon16 icon-search' /> View</a>
						"}
					if(T.owner.mob)
						content += {"
							<a href='?_src_=holder;adminmoreinfo=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-search' /> ?</a>
							<a href='?_src_=holder;adminplayeropts=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-clipboard' /> PP</a>
							<a href='?_src_=vars;Vars=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-clipboard' /> VV</a>
							<a href='?_src_=holder;subtlemessage=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-mail-closed' /> SM</a>
							<a href='?_src_=holder;adminplayerobservefollow=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-arrowthick-1-e' /> FLW</a>
							<a href='?_src_=holder;secretsadmin=check_antagonist'><img border='0' width='16' height='16' class='uiIcon16 icon-clipboard' /> CA</a>
							[ai_found ? " <a href='?_src_=holder;adminchecklaws=\ref[T.owner.mob]'><img width='16' height='16' class='uiIcon16 icon-clipboard' /> CL</a>" : ""]
							"}
					content += {"
						<a href='?src=\ref[T];user=\ref[src];action=monitor_admin_ticket;ticket=\ref[T];reloadlist=1' class='monitor-button'><img border='0' width='16' height='16' class='uiIcon16 icon-pin-s' /> <span>[!T.is_monitor(usr.client) ? "Un" : ""]Monitor</span></a>
						<a href='?src=\ref[T];user=\ref[src];action=resolve_admin_ticket;ticket=\ref[T];reloadlist=1' class='resolve-button'><img border='0' width='16' height='16' class='uiIcon16 icon-check' /> <span>[T.resolved ? "Un" : ""]Resolve</span></a>
						</p>"}

		if(resolved.len > 0)
			content += "<p class='info-bar resolved emboldened large-font'>Resolved Adminhelps ([resolved.len]/[tickets_list.len]):</p>"
			for(var/datum/admin_ticket/T in resolved)
				/*if(!T.owner)
					continue*/

				if(!T.owner)
					content += {"<p class='ticket-bar'>
						<span class='ticket-number'>#[T.ticket_id]</span>
						<b>[T.title]</b><br />
						<b>Owner:</b> <b>[T.owner_ckey] (DC)</b>
						<a href='?src=\ref[T];user=\ref[src];action=view_admin_ticket;ticket=\ref[T]'><img border='0' width='16' height='16' class='uiIcon16 icon-search' /> View</a>
						<a href='?src=\ref[T];user=\ref[src];action=monitor_admin_ticket;ticket=\ref[T];reloadlist=1' class='monitor-button'><img border='0' width='16' height='16' class='uiIcon16 icon-pin-s' /> <span>[!T.is_monitor(usr.client) ? "Un" : ""]Monitor</span></a>
						<a href='?src=\ref[T];user=\ref[src];action=resolve_admin_ticket;ticket=\ref[T];reloadlist=1' class='resolve-button'><img border='0' width='16' height='16' class='uiIcon16 icon-check' /> <span>[T.resolved ? "Un" : ""]Resolve</span></a>
						</p>"}
				else
					var/ai_found = (T.owner && isAI(get_ckey(T.owner)))
					content += {"<p class='ticket-bar'>
						<span class='ticket-number'>#[T.ticket_id]</span>
						<b>[T.title]</b><br />
						<b>Owner:</b> <b>[key_name(T.owner, 1)]</b><br />
						[T.handling_admin ? " <b>Admin:</b> [T.handling_admin]<br />" : ""]
						<a href='?src=\ref[T];user=\ref[src];action=view_admin_ticket;ticket=\ref[T]'><img border='0' width='16' height='16' class='uiIcon16 icon-search' /> View</a>
						"}
					if(T.owner.mob)
						content += {"
							<a href='?_src_=holder;adminmoreinfo=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-search' /> ?</a>
							<a href='?_src_=holder;adminplayeropts=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-clipboard' /> PP</a>
							<a href='?_src_=vars;Vars=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-clipboard' /> VV</a>
							<a href='?_src_=holder;subtlemessage=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-mail-closed' /> SM</a>
							<a href='?_src_=holder;adminplayerobservefollow=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-arrowthick-1-e' /> FLW</a>
							<a href='?_src_=holder;secretsadmin=check_antagonist'><img border='0' width='16' height='16' class='uiIcon16 icon-clipboard' /> CA</a>
							[ai_found ? " <a href='?_src_=holder;adminchecklaws=\ref[T.owner.mob]'><img border='0' width='16' height='16' class='uiIcon16 icon-clipboard' /> CL</a>" : ""]
								"}
					content += {"
						<a href='?src=\ref[T];user=\ref[src];action=monitor_admin_ticket;ticket=\ref[T];reloadlist=1' class='monitor-button'><img border='0' width='16' height='16' class='uiIcon16 icon-pin-s' /> <span>[!T.is_monitor(usr.client) ? "Un" : ""]Monitor</span></a>
						<a href='?src=\ref[T];user=\ref[src];action=resolve_admin_ticket;ticket=\ref[T];reloadlist=1' class='resolve-button'><img border='0' width='16' height='16' class='uiIcon16 icon-check' /> <span>[T.resolved ? "Un" : ""]Resolve</span></a>
						</p>"}
	else
		content += "<p class='info-bar'><a href='?user=\ref[src];action=refresh_admin_ticket_list;flag=[flag]'>Refresh List</a></p>"

		if(tickets_list.len == 0)
			content += "<p class='info-bar emboldened'>There are no Adminhelps in the system</p>"
		else
			content += "<p class='info-bar emboldened'>Your Adminhelps:</p>"
			for(var/datum/admin_ticket/T in tickets_list)
				if(compare_ckey(T.owner, usr))
					content += {"<p class='ticket-bar [T.resolved ? "resolved" : "unresolved"]'>
						<b>[T.title]</b>
						<a href='?src=\ref[T];user=\ref[src];action=view_admin_ticket;ticket=\ref[T]'><img border='0' width='16' height='16' class='uiIcon16 icon-search' /> View</a>
						</p>"}

	var/html = get_html("Adminhelp Panel", "", "", content)

	usr << browse(null, "window=ViewTickets")
	usr << browse(html, "window=ViewTickets")

/client/verb/afk()
	set name = "AFK"
	set category = "OOC"
	set desc = "Report to Admins and your peers that your will go AFK"

	if(src.mob)
		var/mob/M = src.mob

		if(!M || !M.job)
			src << "<p class='info-bar emboldened'>You do not appear to have a job, so reporting being AFK is not necessary.</p>"
		else
			var/time = input(src, "How long do you expect to be gone?") in list("5 minutes","10 minutes","15 minutes","30 minutes","Whole round","Unknown")

			if(!time)
				return

			var/reason = input(src, "Do you have time to give a reason? If so, please give it:") as null|text
			var/alert_admins = 0
			if(M.job == "AI" || istype(M, /mob/living/silicon))
				alert_admins = 1
			else if(M.job == "Captain" || M.job == "Head of Personnel" || M.job == "Head of Security" || M.job == "Chief Engineer" || M.job == "Research Director" || M.job == "Chief Medical Officer")
				alert_admins = 1

			if(alert_admins)
				admin_ticket("I need to go AFK as '[M.job]' for duration of '[time]' [reason ? " with the reason: '[reason]'" : ""]")
			else
				src << "<p class='info-bar emboldened'>Admins will not be specifically alerted, because you are not in a critical station role.</p>"
	else
		src << "<p class='info-bar emboldened'>It is not necessary to report being AFK if you are not in the game.</p>"
