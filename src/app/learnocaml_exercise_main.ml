(* This file is part of Learn-OCaml.
 *
 * Copyright (C) 2016 OCamlPro.
 *
 * Learn-OCaml is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * Learn-OCaml is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. *)

open Js_utils
open Lwt.Infix
open Learnocaml_common
open Learnocaml_data

let init_tabs, select_tab =
  let names = [ "text" ; "toplevel" ; "report" ; "editor"; "more" ] in
  let current = ref "text" in
  let select_tab name =
    set_arg "tab" name ;
    Manip.removeClass
      (find_component ("learnocaml-exo-button-" ^ !current))
      "front-tab" ;
    Manip.removeClass
      (find_component ("learnocaml-exo-tab-" ^ !current))
      "front-tab" ;
    Manip.enable
      (find_component ("learnocaml-exo-button-" ^ !current)) ;
    Manip.addClass
      (find_component ("learnocaml-exo-button-" ^ name))
      "front-tab" ;
    Manip.addClass
      (find_component ("learnocaml-exo-tab-" ^ name))
      "front-tab" ;
    Manip.disable
      (find_component ("learnocaml-exo-button-" ^ name)) ;
    current := name in
  let init_tabs () =
    current := begin try
        let requested = arg "tab" in
        if List.mem requested names then requested else "text"
      with Not_found -> "text"
    end ;
    List.iter
      (fun name ->
         Manip.removeClass
           (find_component ("learnocaml-exo-button-" ^ name))
           "front-tab" ;
         Manip.removeClass
           (find_component ("learnocaml-exo-tab-" ^ name))
           "front-tab" ;
         Manip.Ev.onclick
           (find_component ("learnocaml-exo-button-" ^ name))
           (fun _ -> select_tab name ; true))
      names ;
    select_tab !current in
  init_tabs, select_tab

let display_report exo report =
  let score, failed = Report.result report in
  let report_button = find_component "learnocaml-exo-button-report" in
  Manip.removeClass report_button "success" ;
  Manip.removeClass report_button "failure" ;
  Manip.removeClass report_button "partial" ;
  let grade =
    let max = Learnocaml_exercise.(access File.max_score exo) in
    if max = 0 then 999 else score * 100 / max
  in
  if grade >= 100 then begin
    Manip.addClass report_button "success" ;
    Manip.replaceChildren report_button
      Tyxml_js.Html5.[ pcdata [%i"Report"] ]
  end else if grade = 0 then begin
    Manip.addClass report_button "failure" ;
    Manip.replaceChildren report_button
      Tyxml_js.Html5.[ pcdata [%i"Report"] ]
  end else begin
    Manip.addClass report_button "partial" ;
    let pct = Format.asprintf "%2d%%" grade in
    Manip.replaceChildren report_button
      Tyxml_js.Html5.[ pcdata [%i"Report"] ;
                       span ~a: [ a_class [ "score" ] ] [ pcdata pct ]]
  end ;
  let report_container = find_component "learnocaml-exo-tab-report" in
  Manip.setInnerHtml report_container
    (Format.asprintf "%a" Report.(output_html ~bare: true) report) ;
  grade

let display_descr ex_meta =
  let open Tyxml_js.Html5 in
  let open Learnocaml_data.Exercise in
  div ~a:[ a_class [ "descr" ] ] [
    h2 ~a:[ a_class [ "learnocaml-exo-meta-category" ] ] [ pcdata ex_meta.Meta.title ] ;
    p [ match ex_meta.Meta.short_description with
        | None -> pcdata [%i"No description available."]
        | Some text -> pcdata text ] ;
  ]

let display_stars ex_meta =
  let open Tyxml_js.Html5 in
  let open Learnocaml_data.Exercise in
  div ~a:[ a_class [ "stars" ] ] [
    let num = 5 * int_of_float (ex_meta.Meta.stars *. 2.) in
    let num = max (min num 40) 0 in
    let alt = Format.asprintf [%if"difficulty: %d / 40"] num in
    let src = Format.asprintf "icons/stars_%02d.svg" num in
    img ~alt ~src ()
  ]

let display_kind ex_meta =
  let open Tyxml_js.Html5 in
  let open Learnocaml_data.Exercise in
  div ~a:[ a_class [ "length" ] ] [
    match ex_meta.Meta.kind with
    | Exercise.Meta.Project -> pcdata [%i"project"]
    | Exercise.Meta.Problem -> pcdata [%i"problem"]
    | Exercise.Meta.Exercise -> pcdata [%i"exercise"] ]

(* Inefficient version: Reload the exercise description each time. *)
let display_exercise_more content_id token id =
  let open Tyxml_js.Html5 in
  let open Learnocaml_data.Exercise in
  let content = find_component content_id in
  token >>= fun token ->
  Server_caller.fetch_exercise token id >>= fun (meta, _, _) ->
  let descr =
    a ~a:[ a_href ("exercise.html#id=" ^ id ^ "&action=open") ;
           a_class [ "exercise" ] ] [
      display_descr meta ;
      div ~a:[  ] [
        display_stars meta ;
        display_kind meta ;
      ] ]
  in
  Manip.replaceChildren content [ descr ];
  Lwt.return ()

let display_list ?(sep=Tyxml_js.Html5.pcdata ", ") l =
  let open Tyxml_js.Html5 in
  let rec gen acc = function
    | [] -> [ pcdata "" ]
    | a :: [] -> a :: acc
    | a :: ((_ :: _) as rem) ->
        gen (sep :: (a  :: acc)) rem
  in
  gen [] l |> List.rev


let display_authors authors =
  let open Tyxml_js.Html5 in
  let author (name, mail) =
    span [ pcdata name;
           pcdata " <";
           a ~a:[ a_href ("mailto:" ^ mail) ]
             [ pcdata mail ];
           pcdata ">"
         ] in
  display_list @@ List.map author authors

let display_skill_more skill content_id =
  let open Tyxml_js.Html5 in
  let open Learnocaml_data.Exercise in
  let content = find_component content_id in
  let req = match skill with
      `Focus s -> Learnocaml_api.Focusing_skill s
    | `Requirements s -> Learnocaml_api.Requiring_skill s
  in
  Server_caller.request_exn req >>= fun exs ->
  Manip.replaceChildren content @@ display_list @@ List.map pcdata exs;
  Lwt.return ()

let display_more token ex_meta id =
  let open Learnocaml_data.Exercise in
  let open Tyxml_js.Html5 in
  let display_skill_link content_id s =
    let skill = match s with `Focus s | `Requirements s -> s in
    let cid = Format.asprintf "%s-%s" content_id skill in
    let displayed = ref false in
    div [
      p ~a:[ a_onclick
               (fun _ ->
                  if not (!displayed) then
                    (ignore @@ display_skill_more s cid;
                     displayed := true)
                  else
                    (Manip.removeChildren (find_component cid);
                     displayed := false) ;
                  true) ]
        [ pcdata skill ] ;
      div ~a:[a_id cid;
              a_class [ "learnocaml-exo-meta-category" ] ] [] ]
  in
  let display_exercise_link content_id e =
    let cid = Format.asprintf "%s-%s" content_id e in
    let displayed = ref false in
    div [
      p ~a:[ a_onclick
               (fun _ ->
                  if not (!displayed) then
                    (ignore @@ display_exercise_more cid token e;
                     displayed := true)
                  else
                    (Manip.removeChildren (find_component cid);
                     displayed := false) ;
                  true) ]
        [ pcdata e ] ;
      div ~a:[a_id cid;
              a_class [ "learnocaml-exo-meta-category" ] ] [] ]
  in
  let ident =
    Format.asprintf "%s %s" [%i "Exercise identifier:" ] id in
  let authors =
    span [ pcdata [%i "Author(s):" ] ] :: display_authors ex_meta.Meta.author in
  let focus =
    [%i "Skills trained:"],
    display_list @@
    List.map (fun s ->
        display_skill_link "learnocaml-exo-focus-more" (`Focus s))
      (ex_meta.Meta.focus) in
  let requirements =
    [%i "Skills required:"],
    display_list @@
    List.map (fun s ->
        display_skill_link "learnocaml-exo-requirements-more" (`Requirements s))
      ex_meta.Meta.requirements  in
  let backward =
    [%i "Previous exercises:"],
    display_list ~sep:(pcdata "") @@
    List.map (display_exercise_link "learnocaml-exo-backward-more")
      ex_meta.Meta.backward in
  let forward =
      [%i "Exercises following:"],
      display_list ~sep:(pcdata "") @@
      List.map (display_exercise_link "learnocaml-exo-forward-more")
        ex_meta.Meta.forward in
  let tab = find_component "learnocaml-exo-tab-more" in
  Manip.replaceChildren tab @@
  Tyxml_js.Html5.([
    h1 ~a:[ a_class [ "learnocaml-exo-meta-title" ] ]
      [ pcdata [%i "Metadata" ] ] ;

    div ~a:[ a_id "learnocaml-exo-content-more" ]
      (display_descr ex_meta ::
       display_kind ex_meta ::
       display_stars ex_meta ::
       p [ pcdata ident ] ::
       p authors ::
       List.map (fun (title, values) ->
           div
             (h2 ~a:[ a_class [ "learnocaml-exo-meta-category-title" ] ] [ pcdata title ] ::
              values))
         [ focus ; requirements ; backward ; forward ])
  ])

let set_string_translations () =
  let translations = [
    "txt_preparing", [%i"Preparing the environment"];
    "learnocaml-exo-button-editor", [%i"Editor"];
    "learnocaml-exo-button-toplevel", [%i"Toplevel"];
    "learnocaml-exo-button-report", [%i"Report"];
    "learnocaml-exo-button-text", [%i"Exercise"];
    "learnocaml-exo-editor-pane", [%i"Editor"];
    "txt_grade_report", [%i"Click the Grade button to get your report"];
  ] in
  List.iter
    (fun (id, text) ->
       Manip.setInnerHtml (find_component id) text)
    translations

let make_readonly () =
  match Manip.by_id "learnocaml-exo-editor-pane" with None -> () | Some ed ->
    alert ~title:[%i"TIME OUT"]
      [%i"The deadline for this exercise has expired. Any changes you make will \
          remain local only."]

let () =
  Lwt.async_exception_hook := begin function
    | Failure message -> fatal message
    | Server_caller.Cannot_fetch message -> fatal message
    | exn -> fatal (Printexc.to_string exn)
  end ;
  (match Js_utils.get_lang() with Some l -> Ocplib_i18n.set_lang l | None -> ());
  Lwt.async @@ fun () ->
  set_string_translations ();
  Learnocaml_local_storage.init () ;
  let token =
    try
      Learnocaml_local_storage.(retrieve sync_token) |>
      Lwt.return
    with Not_found ->
      Server_caller.request_exn (Learnocaml_api.Create_token None)
      >|= fun token ->
      Learnocaml_local_storage.(store sync_token) token;
      token
  in
  (* ---- launch everything --------------------------------------------- *)
  let toplevel_buttons_group = button_group () in
  disable_button_group toplevel_buttons_group (* enabled after init *) ;
  let toplevel_toolbar = find_component "learnocaml-exo-toplevel-toolbar" in
  let editor_toolbar = find_component "learnocaml-exo-editor-toolbar" in
  let nickname_div = find_component "learnocaml-nickname" in
  (match Learnocaml_local_storage.(retrieve nickname) with
   | nickname -> Manip.setInnerText nickname_div nickname
   | exception Not_found -> ());
  let toplevel_button = button ~container: toplevel_toolbar ~theme: "dark" in
  let editor_button = button ~container: editor_toolbar ~theme: "light" in
  let id = arg "id" in
  let exercise_fetch =
    token >>= fun token ->
    Server_caller.fetch_exercise token id
  in
  let after_init top =
    exercise_fetch >>= fun (meta, exo, deadline) ->
    begin match Learnocaml_exercise.(decipher File.prelude exo) with
      | "" -> Lwt.return true
      | prelude ->
          Learnocaml_toplevel.load ~print_outcome:true top
            ~message: [%i"loading the prelude..."]
            prelude
    end >>= fun r1 ->
    Learnocaml_toplevel.load ~print_outcome:false top
      (Learnocaml_exercise.(decipher File.prepare exo)) >>= fun r2 ->
    if not r1 || not r2 then failwith [%i"error in prelude"] ;
    Learnocaml_toplevel.set_checking_environment top >>= fun () ->
    Lwt.return () in
  let timeout_prompt =
    Learnocaml_toplevel.make_timeout_popup
      ~on_show: (fun () -> select_tab "toplevel")
      () in
  let flood_prompt =
    Learnocaml_toplevel.make_flood_popup
      ~on_show: (fun () -> select_tab "toplevel")
      () in
  let history =
    let storage_key =
      Learnocaml_local_storage.exercise_toplevel_history id in
    let on_update self =
      Learnocaml_local_storage.store storage_key
        (Learnocaml_toplevel_history.snapshot self) in
    let snapshot =
      Learnocaml_local_storage.retrieve storage_key in
    Learnocaml_toplevel_history.create
      ~gettimeofday
      ~on_update
      ~max_size: 99
      ~snapshot () in
  let toplevel_launch =
    Learnocaml_toplevel.create
      ~after_init ~timeout_prompt ~flood_prompt
      ~on_disable_input: (fun _ -> disable_button_group toplevel_buttons_group)
      ~on_enable_input: (fun _ -> enable_button_group toplevel_buttons_group)
      ~container:(find_component "learnocaml-exo-toplevel-pane")
      ~history () in
  init_tabs () ;
  toplevel_launch >>= fun top ->
  exercise_fetch >>= fun (ex_meta, exo, deadline) ->
  (match deadline with
   | None -> ()
   | Some 0. -> make_readonly ()
   | Some t ->
       match Manip.by_id "learnocaml-countdown" with
       | Some elt -> countdown elt t ~ontimeout:make_readonly
       | None -> ());
  let solution = match Learnocaml_local_storage.(retrieve (exercise_state id)) with
    | { Answer.report = Some report ; solution } ->
        let _ : int = display_report exo report in
        Some solution
    | { Answer.report = None ; solution } ->
        Some solution
    | exception Not_found -> None in
  (* ---- toplevel pane ------------------------------------------------- *)
  begin toplevel_button
      ~group: toplevel_buttons_group
      ~icon: "cleanup" [%i"Clear"] @@ fun () ->
    Learnocaml_toplevel.clear top ;
    Lwt.return ()
  end ;
  begin toplevel_button
      ~icon: "reload" [%i"Reset"] @@ fun () ->
    toplevel_launch >>= fun top ->
    disabling_button_group toplevel_buttons_group (fun () -> Learnocaml_toplevel.reset top)
  end ;
  begin toplevel_button
      ~group: toplevel_buttons_group
      ~icon: "run" [%i"Eval phrase"] @@ fun () ->
    Learnocaml_toplevel.execute top ;
    Lwt.return ()
  end ;
  (* ---- text pane ----------------------------------------------------- *)
  let text_container = find_component "learnocaml-exo-tab-text" in
  let text_iframe = Dom_html.createIframe Dom_html.document in
  Manip.replaceChildren text_container
    Tyxml_js.Html5.[ h1 [ pcdata ex_meta.Exercise.Meta.title ] ;
                     Tyxml_js.Of_dom.of_iFrame text_iframe ] ;
  let prelude = Learnocaml_exercise.(decipher File.prelude exo) in
  if prelude <> "" then begin
    let open Tyxml_js.Html5 in
    let state = ref (match arg "prelude" with
        | exception Not_found -> true
        | "shown" -> true
        | "hidden" -> false
        | _ -> failwith "Bad format for argument prelude.") in
    let prelude_btn = button [] in
    let prelude_title = h1 [ pcdata [%i"OCaml prelude"] ;
                             prelude_btn ] in
    let prelude_container =
      pre ~a: [ a_class [ "toplevel-code" ] ]
        (Learnocaml_toplevel_output.format_ocaml_code prelude) in
    let update () =
      if !state then begin
        Manip.replaceChildren prelude_btn [ pcdata ("↳ "^[%i"Hide"]) ] ;
        Manip.SetCss.display prelude_container "" ;
        set_arg "prelude" "shown"
      end else begin
        Manip.replaceChildren prelude_btn [ pcdata ("↰ "^[%i"Show"]) ] ;
        Manip.SetCss.display prelude_container "none" ;
        set_arg "prelude" "hidden"
      end in
    update () ;
    Manip.Ev.onclick prelude_btn
      (fun _ -> state := not !state ; update () ; true) ;
    Manip.appendChildren text_container
      Tyxml_js.Html5.[ prelude_title ; prelude_container ]
  end ;
  display_more token ex_meta id;
  Js.Opt.case
    (text_iframe##.contentDocument)
    (fun () -> failwith "cannot edit iframe document")
    (fun d ->
       let mathjax_url =
         "js/mathjax/MathJax.js"
       in
       let mathjax_config =
         "MathJax.Hub.Config({\n\
         \  jax: [\"input/AsciiMath\", \"output/HTML-CSS\"],\n\
         \  extensions: [],\n\
         \  elements: [\"learnocaml-exo-tab-text\"],\n\
         \  showMathMenu: false,\n\
         \  showMathMenuMSIE: false,\n\
         \  \"HTML-CSS\": {\n\
         \    imageFont: null\n\
         \  }
          });"
        (* the following would allow comma instead of dot for the decimal separator,
           but should depend on the language the exercise is in, not the language of the
           app
           "AsciiMath: {\n\
           \  decimal: \"" ^[%i"."]^ "\"\n\
            },\n"
         *)
       in
       (* Looking for the description in the correct language. *)
       let descr =
         let lang = "" in
         try
           List.assoc lang (Learnocaml_exercise.(access File.descr exo))
         with
           Not_found ->
             try List.assoc "" (Learnocaml_exercise.(access File.descr exo))
             with Not_found -> [%i "No description available for this exercise." ]
         in
       let html = Format.asprintf
           "<!DOCTYPE html>\
            <html><head>\
            <title>%s - exercise text</title>\
            <meta charset='UTF-8'>\
            <link rel='stylesheet' href='css/learnocaml_standalone_description.css'>\
            <script type='text/x-mathjax-config'>%s</script>
            <script type='text/javascript' src='%s'></script>\
            </head>\
            <body>\
            %s\
            </body>\
            </html>"
           ex_meta.Exercise.Meta.title
           mathjax_config
           mathjax_url
           descr in
       d##open_;
       d##write (Js.string html);
       d##close) ;
  (* ---- editor pane --------------------------------------------------- *)
  let editor_pane = find_component "learnocaml-exo-editor-pane" in
  let editor = Ocaml_mode.create_ocaml_editor (Tyxml_js.To_dom.of_div editor_pane) in
  let ace = Ocaml_mode.get_editor editor in
  Ace.set_contents ace
    (match solution with
     | Some solution -> solution
     | None -> Learnocaml_exercise.(access File.template exo)) ;
  Ace.set_font_size ace 18;
  begin editor_button
      ~icon: "cleanup" [%i"Reset"] @@ fun () ->
    Ace.set_contents ace (Learnocaml_exercise.(access File.template exo)) ;
    Lwt.return ()
  end ;
  begin editor_button
      ~icon: "sync" [%i"Sync"] @@ fun () ->
    token >>= fun token ->
    let solution = Ace.get_contents ace in
    let report, grade =
      match Learnocaml_local_storage.(retrieve (exercise_state id)) with
      | { Answer.report ; grade } -> report, grade
      | exception Not_found -> None, None in
    Learnocaml_local_storage.(store (exercise_state id))
      { Answer.report ; grade ; solution ;
        mtime = gettimeofday () } ;
    sync token >|= fun save ->
    let solution =
      (SMap.find
         id save.Save.all_exercise_states)
      .Answer.solution
    in
    Ace.set_contents ace solution
  end ;
  begin editor_button
      ~icon: "download" [%i"Download"] @@ fun () ->
    let name = id ^ ".ml" in
    let contents = Js.string (Ace.get_contents ace) in
    Learnocaml_common.fake_download ~name ~contents ;
    Lwt.return ()
  end ;
  let typecheck set_class =
    Learnocaml_toplevel.check top (Ace.get_contents ace) >>= fun res ->
    let error, warnings =
      match res with
      | Toploop_results.Ok ((), warnings) -> None, warnings
      | Toploop_results.Error (err, warnings) -> Some err, warnings in
    let transl_loc { Toploop_results.loc_start ; loc_end } =
      { Ocaml_mode.loc_start ; loc_end } in
    let error = match error with
      | None -> None
      | Some { Toploop_results.locs ; msg ; if_highlight } ->
          Some { Ocaml_mode.locs = List.map transl_loc locs ;
                 msg = (if if_highlight <> "" then if_highlight else msg) } in
    let warnings =
      List.map
        (fun { Toploop_results.locs ; msg ; if_highlight } ->
           { Ocaml_mode.loc = transl_loc (List.hd locs) ;
             msg = (if if_highlight <> "" then if_highlight else msg) })
        warnings in
    Ocaml_mode.report_error ~set_class editor error warnings  >>= fun () ->
    Ace.focus ace ;
    Lwt.return () in
  begin editor_button
      ~group: toplevel_buttons_group
      ~icon: "typecheck" [%i"Check"] @@ fun () ->
    typecheck true
  end ;
  begin toplevel_button
      ~group: toplevel_buttons_group
      ~icon: "run" [%i"Eval code"] @@ fun () ->
    Learnocaml_toplevel.execute_phrase top (Ace.get_contents ace) >>= fun _ ->
    Lwt.return ()
  end ;
  (* ---- main toolbar -------------------------------------------------- *)
  let exo_toolbar = find_component "learnocaml-exo-toolbar" in
  let toolbar_button = button ~container: exo_toolbar ~theme: "light" in
  begin toolbar_button
      ~icon: "list" [%i"Exercises"] @@ fun () ->
    Dom_html.window##.location##assign
      (Js.string "index.html#activity=exercises") ;
    Lwt.return ()
  end ;
  let messages = Tyxml_js.Html5.ul [] in
  let callback text =
    Manip.appendChild messages Tyxml_js.Html5.(li [ pcdata text ]) in
  let worker = ref (Grading_jsoo.get_grade ~callback exo) in
  begin toolbar_button
      ~icon: "reload" [%i"Grade!"] @@ fun () ->
    let aborted, abort_message =
      let t, u = Lwt.task () in
      let btn = Tyxml_js.Html5.(button [ pcdata [%i"abort"] ]) in
      Manip.Ev.onclick btn (fun _ -> Lwt.wakeup u () ; true) ;
      let div =
        Tyxml_js.Html5.(div ~a: [ a_class [ "dialog" ] ]
                          [ pcdata [%i"Grading is taking a lot of time, "] ;
                            btn ;
                            pcdata " ?" ]) in
      Manip.SetCss.opacity div (Some "0") ;
      t, div in
    Manip.replaceChildren messages
      Tyxml_js.Html5.[ li [ pcdata [%i"Launching the grader"] ] ] ;
    show_loading ~id:"learnocaml-exo-loading" [ messages ; abort_message ] ;
    Lwt_js.sleep 1. >>= fun () ->
    let solution = Ace.get_contents ace in
    Learnocaml_toplevel.check top solution >>= fun res ->
    match res with
    | Toploop_results.Ok ((), _) ->
        let grading =
          !worker solution >>= fun (report, _, _, _) ->
          Lwt.return report in
        let abortion =
          Lwt_js.sleep 5. >>= fun () ->
          Manip.SetCss.opacity abort_message (Some "1") ;
          aborted >>= fun () ->
          Lwt.return Learnocaml_report.[ Message ([ Text [%i"Grading aborted by user."] ], Failure) ] in
        Lwt.pick [ grading ; abortion ] >>= fun report ->
        let grade = display_report exo report in
        worker := Grading_jsoo.get_grade ~callback exo ;
        Learnocaml_local_storage.(store (exercise_state id))
          { Answer.grade = Some grade ; solution ; report = Some report ;
            mtime = max_float } ; (* To ensure server time will be used *)
        token >>= sync >>= fun save ->
        select_tab "report" ;
        Lwt_js.yield () >>= fun () ->
        hide_loading ~id:"learnocaml-exo-loading" () ;
        Lwt.return ()
    | Toploop_results.Error _ ->
        let msg =
          Learnocaml_report.[ Text [%i"Error in your code."] ; Break ;
                   Text [%i"Cannot start the grader if your code does not typecheck."] ] in
        let report = Learnocaml_report.[ Message (msg, Failure) ] in
        let grade = display_report exo report in
        Learnocaml_local_storage.(store (exercise_state id))
          { Answer.grade = Some grade ; solution ; report = Some report ;
            mtime = gettimeofday () } ;
        select_tab "report" ;
        Lwt_js.yield () >>= fun () ->
        hide_loading ~id:"learnocaml-exo-loading" () ;
        typecheck true
  end ;
  (* ---- return -------------------------------------------------------- *)
  toplevel_launch >>= fun _ ->
  typecheck false >>= fun () ->
  hide_loading ~id:"learnocaml-exo-loading" () ;
  Lwt.return ()
;;
