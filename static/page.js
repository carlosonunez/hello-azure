function loadRandomImage() {
  $.ajax({
    url: "/random_image",
    type: "GET",
    dataType: "html",
    success: function(data) {
      $('#image').html(generateImageHtml(data))
    },
    error: function(data) {
      return $('#image').html('<p style="color: red"><center>Unable to get image.</center></p>')
    }
  })
}

function increaseClickCount(count) {
  $('#click_count').text(count);
}

function generateImageHtml(imagePath) {
  imageName = imagePath.split('/').pop(-1).replace('.png','')
  return '<img src="' + imagePath + '"></img><p>Congratulations! You got a ' + imageName + '!'
}

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
        increaseClickCount(data);
        loadRandomImage();
      },
      error: function(xhr, status) {
        console.log("Unable to update click count.");
      }
    });
  })
});
