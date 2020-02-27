$( "#click_count" ).ready(function() {
  $.ajax({
    url: "/clicks",
    type: "GET",
    dataType: "html",
    success: function(data) {
      $('#click_count').text(data);
    },
    error: function(xhr, status) {
      console.log("Unable to fetch click count.");
    }
  });
});
