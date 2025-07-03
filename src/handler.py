import time
import runpod
import requests
import base64
from io import BytesIO
from PIL import Image
from requests.adapters import HTTPAdapter, Retry

LOCAL_URL = "http://127.0.0.1:3000/sdapi/v1"

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))


# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def wait_for_service(url):
    """
    Check if the service is ready to receive requests.
    """
    retries = 0

    while True:
        try:
            requests.get(url, timeout=120)
            return
        except requests.exceptions.RequestException:
            retries += 1

            # Only log every 15 retries so the logs don't get spammed
            if retries % 15 == 0:
                print("Service not ready yet. Retrying...")
        except Exception as err:
            print("Error: ", err)

        time.sleep(0.2)


def run_inference(inference_request):
    """
    Run inference on a request.
    """
    response = automatic_session.post(url=f'{LOCAL_URL}/txt2img',
                                      json=inference_request, timeout=600)
    return response.json()


def face_segment(image_data):
    """
    Process an image through the face segmentation preprocessor.
    
    Args:
        image_data: Base64 encoded image or path to image file
    
    Returns:
        Processed image with face segmentation
    """
    # Check if input is a base64 string or a file path
    if isinstance(image_data, str) and image_data.startswith('data:image'):
        # It's a base64 string
        image_content = image_data
    elif isinstance(image_data, str):
        # It's a file path
        try:
            with open(image_data, 'rb') as img_file:
                img = Image.open(img_file).convert('RGB')
                buffered = BytesIO()
                img.save(buffered, format="PNG")
                image_content = f"data:image/png;base64,{base64.b64encode(buffered.getvalue()).decode('utf-8')}"
        except Exception as e:
            return {"error": f"Failed to open image file: {str(e)}"}
    else:
        return {"error": "Invalid image data format"}
    
    # Prepare the request for the ControlNet preprocessor
    payload = {
        "controlnet_module": "mediapipe_face_mesh",  # Face segmentation preprocessor
        "controlnet_input_images": [image_content],
        "controlnet_processor_res": 512,
        "controlnet_threshold_a": 64,
        "controlnet_threshold_b": 64
    }
    
    try:
        response = automatic_session.post(
            url=f'{LOCAL_URL}/controlnet/detect',
            json=payload,
            timeout=120
        )
        return response.json()
    except Exception as e:
        return {"error": f"Face segmentation request failed: {str(e)}"}


# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    """
    This is the handler function that will be called by the serverless.
    """
    
    # Check if the request is for face segmentation
    if event["input"].get("task") == "face_segment":
        return face_segment(event["input"].get("image", ""))
    
    # Default to regular txt2img inference
    json = run_inference(event["input"])
    
    # return the output that you want to be returned like pre-signed URLs to output artifacts
    return json


if __name__ == "__main__":
    wait_for_service(url=f'{LOCAL_URL}/sd-models')
    print("WebUI API Service is ready. Starting RunPod Serverless...")
    runpod.serverless.start({"handler": handler})