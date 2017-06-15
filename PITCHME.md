# Instance-Level Segmentation for Autonomous Driving with Deep Densely Connected MRFs

---

## Introduction


---

## Dataset
- Cityscapes <-> Kitti
- size (train, test, val)
- quality (resolution, instances)
- labeling quality (class, instances)

---

## Pipeline

### Overview
#### Prediction
- cut image patches
    - overlapping
    - different sizes for different object distances
- predict objects in patches
    - convolutional neural network
    - objects labels ordered by depth
    - max 5 objects per patch
- reassamble predictions
    - markov random field
    - max 8 objects per image
- <!-- IMAGE -->

+++

#### Evaluation
- class level:
    - oiu: intersection over union of predicted / groundtruth foreground pixels
- object level:
    - mwc/muc: average rate of groundtruth object coverage
    - average precision: prediced instances vs. groundtruth foreground
    - average recall: groundtruth instances vs predicted foreground
    - average false positive / negative instances
    - average instance precision: match each predicted obejct with > 50% overlapping groundtruth obejct
    - average instance recall: match each groundtruth object with > 50% overlapping prediced object
    - average instance f1-score using above instance precision / recall

+++

#### Training
- separate train and test images
- cut image patches
    - for each image
    - use same cropping scheme as for predictions
    - order object labelings by depth
- train cnn
    - use pre-trained vgg-16 network with deattached head
    - train using cropped patch-label-pairs of training set
- train mrf
    - merge predictions of test patches
    - use different parameter settings
    - rate parameters by average f_1 score
- <!-- IMAGE -->

+++

### What was provided
- Zhang et al.
    - patch merging using mrf
    - inital cnn (pre-trained)
- Cityscapes
    - image training and validation sets
    - implementation for generating labels
    - (implementation for measuring accuracy)

+++

### Filled gaps
- ordering object labels by depth
    - depth was not available
    - ordered by object's height
- patch cropping
    - reproduced same cropping scheme with same parameters
    - filtering objects if there are too many in a patch
    - (based on example roi-data)
- resampling and reformatting of patch predictions
    - resize to patch shape
    - dump to binary format
    - (based only on output examples, could not reproduce them completely)
- prediction scores
    - Cityscapes only provided average IoU

---

## Convolutional neural network

### Overview
- VGG-16 with slightly modified layers
- x convolutional layers, pooling
    - input 300 x 300
    - output 41 x 41
- <!-- IMAGE -->
- trained to predict objects depth

+++

### Training as provided
- learning rate?
- lr was reduced each 20,000 iterations
- <!-- IMAGE -->

+++

### Bootstrapped training
- finding optimal learning rate and update policy using small portions of the dataset
- <!-- IMAGES -->
- run training in parallell for different generalization settings and choose best
- <!-- IMAGES -->

---

## Markov random field

### Overview
- What is a densely connected MRF?
- What is a solution?
- How is it solved? -- cite Krahenbuhl, complexity?
- Training?

+++

### Model for patch-merging
#### Weights
- local patch prediction term:
    - compare label scores of pixels
    - vectors are similar, encurage same label
    - if they are more similar with shifted values, encurage greater/smaller label
    - $$\sum_x^X \sum_{i, j}^{P_x} \sum_t^T \mu^{t}(y_i, y_j) k^{t}(h_t(p_{x,i}), h_{-t}(p_{x, j}))$$
      for patches $$X$$ with a set of pixels $$P_x$$; a set of allowed shifts $$T$$,
      $$\mu$$ keeps track of valid combiantions of labels and shifts and $$k$$ is a gaussian kernel
- smoothness term:
    - encurage same label for pixels of prediction and region
    - $$\sum_x^X \sum_{i, j}^{P_x} \delta(y_i \neq y_j) k_{pred}(p_{x,i}, p_{x,j}) k_{dist}(i, j)$$
      where $$p_{x,i}$$ contains label predictions in of pixel i patch x
- inter-connected-component:
    - disencurage same labels if regions are not connected
    - use connected regions of foreground (via predictions) as components
    - $$\sum_{c, c'}^C \sum_{i \in P_c} \sum_{j \in P_{c'}} \delta(y_i = y_j)
      for foreground components $$C$$ with pixels $$P_c$$

+++

#### Parameters
- every potential term has own weight; prediction term even one for each patch size (5)
- deviations of gaussian kernel functions (3)
- threshold for separating foreground components (1)
- number of iterations for the approximate inference

+++

### Performance issues
- crf inference is sublinear in the number of edges
- number of edges increase quadratic to the number of pixels
- Cityscapes' is significantly larger than Kitti
- merging patches of an image took ~ 40 minutes ...
- ... and needed ~ 8GB RAM
- solution: compute inference on downscaled predictions (1/16)

+++

### Training by searching parameters
- use patch predictions of trained cnn on test set
- random search:
    - merge patches using different paramters
    - normal distributed parameters around published ones
    - choose by best f1 score

--

## Results

+++

### Examples
#### Local cnn predictions
<!-- IMAGES -->

+++

#### Merged patches
<!-- IMAGES -->

+++

### CNN performance
<!-- TABLE -->

+++

### Merged prediction performance
<!-- TABLE -->

---

## Conclusions