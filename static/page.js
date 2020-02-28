$( document ).ready(function() {
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

  $( "#clicker" ).click(function() {
    $.ajax({
      url: "/click",
      type: "POST",
      dataType: "html",
      success: function(data) {
        $('#click_count').text(data);
      },
      error: function(xhr, status) {
        console.log("Unable to update click count.");
      }
    });
  })
});
