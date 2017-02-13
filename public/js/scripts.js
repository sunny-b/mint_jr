$(function(){

  $("form.brackets select").change(function(){
    var form = $("form.brackets")

    var taxStatus = $("select option:selected").attr("value")

    var request = $.ajax({
      url: form.attr("action"),
      method: form.attr("method"),
      data:{ status: taxStatus }
    });

    request.done(function(data, textStatus, jqXHR) {
      if (jqXHR.status == 200) {
        document.location = data;
      }
    });
  });
});
