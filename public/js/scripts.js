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

  $("form.delete").submit(function(event){
    event.preventDefault();
    event.stopPropagation();

    var form = $(this);
    var total = $("div.total h3")

    var request = $.ajax({
      url: form.attr("action"),
      method: form.attr("method")
    });

    request.done(function(data, textStatus, jqXHR) {
      if (jqXHR.status == 204) {
        form.closest("tr.item").remove();
        total.textContent = "Total: " + data;
      } else if (jqXHR.status == 200) {
        document.location = data;
      }
    });
  });
});
