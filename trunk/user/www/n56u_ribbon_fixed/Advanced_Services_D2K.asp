<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#Services_Menu_7#></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/itoggle.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script>
var $j = jQuery.noConflict();

$j(document).ready(function() {
	init_itoggle('d2k_enable', change_d2k_enabled);
});

</script>
<script>

<% login_state_hook(); %>

var hw_nat_mode = "<% nvram_get_x("", "hw_nat_mode"); %>";

function initial(){
	show_banner(1);
	show_menu(5,7,7);
	show_footer();
	load_body();

	if (found_app_d2k()) {
		showhide_div('tbl_d2k', 1);
		change_d2k_enabled();
	}
}

function applyRule(){
	if(validForm()){
		showLoading();

		document.form.action_mode.value = " Apply ";
		document.form.current_page.value = "/Advanced_Services_D2K.asp";
		document.form.next_page.value = "";

		document.form.submit();
	}
}

function validForm(){
	return true;
}

function done_validating(action){
	refreshpage();
}

function change_d2k_enabled(){
	var v = document.form.d2k_enable[0].checked;

	showhide_div('d2k_show', v);
	inputCtrl(document.form['d2kconf.config'], v);

	/* Аппаратный ускоритель NAT уводит транзитные пакеты мимо Netfilter, и в
	   NFQUEUE не попадает ничего: службы работают, правила стоят, обхода нет.
	   Настройку за владельца не меняем (она влияет на скорость), но и молчать
	   нельзя — симптом выглядит как «D2K не работает». */
	showhide_div('row_d2k_hwnat', v && hw_nat_mode != "2");
}

</script>
<style>
    .d2kconf {
        resize: vertical;
        text-wrap: nowrap;
        font-family: 'Courier New', Courier, mono;
        font-size: 12px;
    }
</style>
</head>

<body onload="initial();" onunLoad="return unload_body();">

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9" >
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
    <input type="hidden" name="current_page" value="Advanced_Services_D2K.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="LANHostConfig;General;Storage;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <!--Sidebar content-->
                <!--=====Beginning of Main Menu=====-->
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li>
                            <div id="subMenu" class="accordion"></div>
                        </li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <!--Body content-->
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_6_5#> - <#Services_Menu_7#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <div class="alert alert-info" style="margin: 10px;"><#Adm_Svc_D2K_Info#></div>

                                    <table width="100%" cellpadding="4" cellspacing="0" class="table" id="tbl_d2k" style="display:none">
                                        <tr>
                                            <th width="50%" style="border-top: 0 none"><a class="help_tooltip" href="javascript:void(0);" onmouseover="openTooltip(this, 25, 7);"><#Adm_Svc_D2K_Enable#></a></th>
                                            <td style="border-top: 0 none">
                                                <div class="main_itoggle">
                                                    <div id="d2k_enable_on_of">
                                                        <input type="checkbox" id="d2k_enable_fake" <% nvram_match_x("", "d2k_enable", "1", "value=1 checked"); %><% nvram_match_x("", "d2k_enable", "0", "value=0"); %>>
                                                    </div>
                                                </div>
                                                <div style="position: absolute; margin-left: -10000px;">
                                                    <input type="radio" name="d2k_enable" id="d2k_enable_1" class="input" value="1" <% nvram_match_x("", "d2k_enable", "1", "checked"); %>/><#checkbox_Yes#>
                                                    <input type="radio" name="d2k_enable" id="d2k_enable_0" class="input" value="0" <% nvram_match_x("", "d2k_enable", "0", "checked"); %>/><#checkbox_No#>
                                                </div>
                                            </td>
                                        </tr>

                                        <tr id="row_d2k_hwnat" style="display:none">
                                            <td colspan="2" style="padding: 0; border: none">
                                                <div class="alert alert-error" style="margin: 10px;"><#Adm_Svc_D2K_HwNat#></div>
                                            </td>
                                        </tr>

                                        <tbody id="d2k_show" style="display:none; border: none">
                                        <tr>
                                            <td colspan="2" style="border: none">
                                                <div class="alert" style="margin: 0 0 10px 0;"><#Adm_Svc_D2K_Panel#></div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th width="50%" style="border-bottom: 0 none;"><a href="javascript:spoiler_toggle('d2k.config')"><#Adm_Svc_D2K_Config#>: <i style="scale: 75%;" class="icon-chevron-down"></i></a></th>
                                            <td style="border-bottom: 0 none;">&nbsp;</td>
                                        </tr>
                                        <tr>
                                            <td colspan="2" style="padding-top: 0px; border: none">
                                                <div id="d2k.config" style="display: none">
                                                    <textarea rows="24" spellcheck="false" maxlength="16384" class="span12 d2kconf" id="d2kconf.config" name="d2kconf.config"><% nvram_dump("d2kconf.config",""); %></textarea>
                                                </div>
                                            </td>
                                        </tr>
                                        </tbody>

                                    </table>

                                    <table class="table">
                                        <tr>
                                            <td style="border: 0 none;">
                                                <center><input class="btn btn-primary" style="width: 219px" onclick="applyRule();" type="button" value="<#CTL_apply#>" /></center>
                                            </td>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    </form>

    <div id="footer"></div>
</div>
</body>
</html>
