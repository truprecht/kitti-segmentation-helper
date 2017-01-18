//
//  inference.cpp
//  densecrf_original
//
//  Created by Ziyu Zhang on 9/22/15.
//  Copyright (c) 2015 Ziyu Zhang. All rights reserved.
//

#include <iostream>
#include <vector>
#include <algorithm>
#include <fstream>
#include <map>

#ifndef __APPLE__
#include <omp.h>
#endif

#ifdef WITH_MPI
#include "mpi.h"
#endif

#define cimg_display 0
#define cimg_use_png
#include <CImg-1.5.9/CImg.h>

#include <Eigen/Core>

#include "densecrf.h"
#include "connected.h"

#define IMAGE_FOLDER "data/image"
#define UNARY_FOLDER "data/input"
#define ROI_FOLDER "data/roi"

#ifdef _MSC_VER
#define DELIM_FOLDER "\\"
#else
#define DELIM_FOLDER "/"
#endif

struct ImageData {
    std::vector<Eigen::Matrix<float, Dynamic, Dynamic, RowMajor> > probs;
  //std::vector<cimg_library::CImg<unsigned char> > maps;
    std::vector<std::vector<int> > rois;
};

int LoadData(const char* fn, Eigen::Matrix<float, Dynamic, Dynamic, RowMajor>& prob, int numLocalStates) {
    std::ifstream ifs(fn, std::ios_base::binary | std::ios_base::in | std::ios_base::ate);
    if (!ifs.is_open()) {
        std::cout << "Error opening file: " << fn << std::endl;
        return -1;
    }
    std::ifstream::pos_type FileSize = ifs.tellg();
    ifs.seekg(0, std::ios_base::beg);
    ifs.read((char*)prob.data(), FileSize);
    ifs.close();
    return 0;
}

int ConvertToProbability(Eigen::Matrix<float, Dynamic, Dynamic, RowMajor>& prob) {
    int v_e = prob.cols();
    int numLocalStates = prob.rows();
    
    for (int v = 0; v != v_e; ++v) {
        float* ptr = prob.data()+v;
        
        float maxVal = *ptr;
        for (int k = 1; k < numLocalStates; ++k) {
            maxVal = std::max(maxVal, *(ptr + v_e*k));
        }
        
        float sumVal = 0;
        for (int k = 0; k < numLocalStates; ++k) {
            float* ptrCur = ptr + v_e*k;
            *ptrCur = std::exp(*ptrCur - maxVal);
            sumVal += *ptrCur;
        }
        
        for (int k = 0; k < numLocalStates; ++k) {
            float* ptrCur = ptr + v_e*k;
            *ptrCur /= sumVal;
        }
    }
    return 0;
}

int ReadAllImageData(const std::string& imageName, const std::vector<std::string>& patchExtensions, struct ImageData& imgData, int numLocalStates) {
    imgData.probs.assign(patchExtensions.size(), Eigen::Matrix<float, Dynamic, Dynamic, RowMajor>());
    imgData.probs.reserve(patchExtensions.size());
    //imgData.maps.assign(patchExtensions.size(), cimg_library::CImg<unsigned char>());
    imgData.rois.assign(patchExtensions.size(), std::vector<int>(4, 0));
    
    for (int k = 0; k < patchExtensions.size(); ++k) {
        std::string roiFile(ROI_FOLDER);
        roiFile.append(DELIM_FOLDER);
        roiFile.append(imageName);
        roiFile.append(patchExtensions[k]);
        roiFile.append(".txt");
        std::ifstream ifs(roiFile.c_str(), std::ios_base::binary | std::ios_base::in);
        if (!ifs.is_open()) {
            std::cout << "Error opening file: " << roiFile.c_str() << std::endl;
            return -1;
        }
        for (int m = 0; m < 4; ++m) {
            ifs >> imgData.rois[k][m];
        }
        ifs.close();
        imgData.rois[k][0]--;
        imgData.rois[k][2]--;
        
        imgData.probs[k].resize(numLocalStates, (imgData.rois[k][1]-imgData.rois[k][0])*(imgData.rois[k][3]-imgData.rois[k][2]));
        std::string datFile(UNARY_FOLDER);
        datFile.append(DELIM_FOLDER);
        datFile.append(imageName);
        datFile.append(patchExtensions[k]);
        datFile.append(".dat");
        LoadData(datFile.c_str(), imgData.probs[k], numLocalStates);
        
        ConvertToProbability(imgData.probs[k]);
        
        /*std::string mapFile(MAP_FOLDER);
        mapFile.append(DELIM_FOLDER);
        mapFile.append(imageName);
        mapFile.append(patchExtensions[k]);
        mapFile.append(".png");
        imgData.maps[k].load(mapFile.c_str());*/
    }
    
    return 0;
}

int ComputeGlobalBinaryProb(Matrix<float, Dynamic, Dynamic, RowMajor>& globalBinaryProb, Matrix<int, Dynamic, Dynamic, RowMajor>& globalBinaryProbMask, int W, int H, ImageData& imgData, float df) {
    globalBinaryProb.resize(2, W*H);
    
    for (int k = 0; k < imgData.rois.size(); ++k) {
        int y1 = imgData.rois[k][0], y2 = imgData.rois[k][1], x1 = imgData.rois[k][2], x2 = imgData.rois[k][3];
        for (int m = y1; m < y2; ++m) {
            globalBinaryProb.block(0, x1+m*W, 1, x2-x1) += imgData.probs[k].block(0,(m-y1)*(x2-x1),1,x2-x1);
            globalBinaryProb.block(1, x1+m*W, 1, x2-x1) += imgData.probs[k].block(1,(m-y1)*(x2-x1),imgData.probs[k].rows()-1,x2-x1).colwise().sum();
        }
    }
    
    int numLocalStates = globalBinaryProb.rows();
    int v_e = W*H;
    
    for (int v = 0; v != v_e; ++v) {
        float* ptr = globalBinaryProb.data()+v;
        
        float sumVal = 0;
        for (int k = 0; k < numLocalStates; ++k) {
            float* ptrCur = ptr + v_e*k;
            sumVal += *ptrCur;
        }
        
        for (int k = 0; k < numLocalStates; ++k) {
            float* ptrCur = ptr + v_e*k;
            *ptrCur /= sumVal;
        }
    }
    
    globalBinaryProbMask.resize(1, globalBinaryProb.cols());
    for (int i = 0; i < globalBinaryProb.cols(); ++i) {
        if (globalBinaryProb(0,i) < globalBinaryProb(1,i) - df/*-0.2,usual;-0.4,fix for 000493*/) {
            globalBinaryProbMask(0,i) = 1;
        } else {
            globalBinaryProbMask(0,i) = 0;
        }
        
    }
    return 0;
}

int ComputeConnectedComponent(std::vector<std::vector<int> >& connCompMembers, std::vector<int>& maxY, std::vector<int>& minY, int* data, int W, int H) {
    
    std::vector<int> connCompMap;
    connCompMap.assign(W*H, 0);
    ConnectedComponents connComp(200);
    connComp.connected(data, &connCompMap[0], W, H, std::equal_to<unsigned char>(), false);
    
    for (int j = 0; j < H; ++j) {
        for (int i = 0; i < W; ++i) {
            int v = i + j*W;
            if (connCompMembers.size() <= connCompMap[v]) {
                connCompMembers.resize(connCompMap[v] + 1, std::vector<int>());
                maxY.resize(connCompMap[v] + 1, 0);
                minY.resize(connCompMap[v] + 1, H);
            }
            connCompMembers[connCompMap[v]].push_back(v);
            maxY[connCompMap[v]] = std::max(maxY[connCompMap[v]], j);
            minY[connCompMap[v]] = std::min(minY[connCompMap[v]], j);
        }
    }
    
    for (int k = int(connCompMembers.size())-1; k>=0; --k) {
        if (*(data + connCompMembers[k][0]) == 0) {
            connCompMembers.erase(connCompMembers.begin() + k);
            maxY.erase(maxY.begin()+k);
            minY.erase(minY.begin()+k);
            //break;
        }
    }
    
    return 0;
}

struct Options {
    std::string patchFilename;
    std::string outputFilename;
    float ws;
    float wm;
    float wl;
    float wi;
    float sp;
    float df;
    float wlocc;
    float slocl;
    float slocpr;
    int iters;
};

int ParseInput(int argc, char** argv, struct Options& options) {
    if (argc < 25) {
        std::cout << "Not enough inputs." << std::endl;
        exit(-1);
    }
    
    for(int k = 1; k < argc; ++k) {
        if(strcmp(argv[k], "-p")==0 && k+1!=argc) {
            options.patchFilename = argv[++k];
        } else if(strcmp(argv[k], "-ws")==0 && k+1!=argc) {
            options.ws = atof(argv[++k]);
        } else if(strcmp(argv[k], "-wm")==0 && k+1!=argc) {
            options.wm = atof(argv[++k]);
        } else if(strcmp(argv[k], "-wl")==0 && k+1!=argc) {
            options.wl = atof(argv[++k]);
        } else if(strcmp(argv[k], "-wi")==0 && k+1!=argc) {
            options.wi = atof(argv[++k]);
        } else if(strcmp(argv[k], "-o")==0 && k+1!=argc) {
            options.outputFilename = argv[++k];
        } else if(strcmp(argv[k], "-sp")==0 && k+1!=argc) {
            options.sp = atof(argv[++k]);
        } else if(strcmp(argv[k], "-df")==0 && k+1!=argc) {
            options.df = atof(argv[++k]);
        } else if(strcmp(argv[k], "-wlocc")==0 && k+1!=argc) {
            options.wlocc = atof(argv[++k]);
        } else if(strcmp(argv[k], "-slocl")==0 && k+1!=argc) {
            options.slocl = atof(argv[++k]);
        } else if(strcmp(argv[k], "-slocpr")==0 && k+1!=argc) {
            options.slocpr = atof(argv[++k]);
        } else if(strcmp(argv[k], "-iters")==0 && k+1!=argc) {
            options.iters = atoi(argv[++k]);
        }
    }
    return 0;
}

int main(int argc, char** argv) {
    char hostname[256];
    hostname[0] = '\0';
#ifndef _MSC_VER
    gethostname(hostname, 255);
    std::cout << hostname << std::endl;
#endif
    
    int ClusterSize = 1;
    int ClusterID = 0;
#ifdef WITH_MPI
    if (!MPI::Is_initialized()) {
        MPI::Init();
    }
    ClusterSize = MPI::COMM_WORLD.Get_size();
    ClusterID = MPI::COMM_WORLD.Get_rank();
#endif
#if defined(__APPLE__) && defined(WITH_MPI)
    if (ClusterID == 0 && ClusterSize>1) {
        int val;
        std::cin >> val;
    }
    if (ClusterSize > 1) {
        MPI::COMM_WORLD.Barrier();
    }
#endif
    
    Options options;
    ParseInput(argc, argv, options);
    std::cout << "Working on dataset: " << options.patchFilename << std::endl;
    std::cout << "Weights for small/medium/large patches, ins pairws: " << options.ws << ", " << options.wm << ", " << options.wl << ", " << options.wi << std::endl;
    std::cout << "Standard deviation for patch potentials: " << options.sp << std::endl;
    std::cout << "Output folder: " << options.outputFilename << std::endl;
    
    int numGlobalStates = 10;
    int numLocalStates = 6;
    
    std::vector<std::string> patchNames;
    std::cout << "Searching for files... ";
    /*
     #ifdef __APPLE__
     std::string patchFilename("/Users/zzhang/Desktop/densecrf_original/densecrf_original/inference/AllPatches_debug.txt");
     #else
     std::string patchFilename("/u/zzhang/densecrf_original/densecrf_original/inference/AllPatches_val119.txt");
     #endif
     */
    std::string patchName;
    std::ifstream ifs(options.patchFilename.c_str(), std::ios_base::binary | std::ios_base::in);
    ifs >> patchName;
    while (patchName.size() > 0) {
        patchNames.push_back(patchName);
        patchName.clear();
        ifs >> patchName;
    }
    ifs.close();
    std::cout << patchNames.size() << " files found." << std::endl;
    
    std::map<std::string, std::vector<std::string> > imagePatchMappings;
    for (int k = 0, k_e = (int)patchNames.size(); k != k_e; ++k) {
        std::string pName = patchNames[k];
        std::string imageName = pName.substr(0, pName.find_first_of("_"));//"000019"
        //std::string imageName = pName.substr(0, pName.size()-5);//"000019"
        std::string patchExtension = pName.substr(pName.find_first_of("_"), 5);//"_1_01"
        //std::string patchExtension = pName.substr(9);//"_1_01"
        std::map<std::string, std::vector<std::string> >::iterator iter2 = imagePatchMappings.find(imageName);
        if (iter2 == imagePatchMappings.end()) {
            imagePatchMappings.insert(std::pair<std::string, std::vector<std::string> >(imageName, std::vector<std::string>(1, patchExtension)));
        } else {
            iter2->second.push_back(patchExtension);
        }
    }
    
    std::vector<std::string> imagesToErase;
    for (std::map<std::string, std::vector<std::string> >::const_iterator iter = imagePatchMappings.begin(), iter_e = imagePatchMappings.end(); iter != iter_e; ++iter) {
        std::string resFileName(options.outputFilename);
        resFileName.append(iter->first);
        resFileName.append(".png");
        
        std::ifstream testFileExistence(resFileName.c_str(), std::ios_base::binary | std::ios_base::in);
        if (testFileExistence.is_open()) {
            std::cout << resFileName << " already exists. Continuing..." << std::endl;
            testFileExistence.close();
            imagesToErase.push_back(iter->first);
        }
        testFileExistence.close();
    }
    for (int i = 0; i < imagesToErase.size(); ++i) {
        imagePatchMappings.erase(imagesToErase[i]);
    }
    std::cout << "Number of images after removing already existed: " << imagePatchMappings.size() << std::endl;

#ifndef __APPLE__
    omp_set_num_threads(2);
#pragma omp parallel for
#endif
    for (int x = ClusterID; x < int(imagePatchMappings.size()); x+=ClusterSize) {
        //for (std::map<std::string, std::vector<std::string> >::const_iterator iter = imagePatchMappings.begin(), iter_e = imagePatchMappings.end(); iter != iter_e; ++iter) {
        std::map<std::string, std::vector<std::string> >::const_iterator iter = imagePatchMappings.begin();
        for (int ix = 0; ix < x; ++ix) {
            ++iter;
        }
#ifdef WITH_MPI
        std::cout << "Processing " << iter->first << " by host: " << hostname << std::endl;
#else
        std::cout << "Processing " << iter->first << std::endl;
#endif
        
        try {
            struct ImageData imgData;
            ReadAllImageData(iter->first, iter->second, imgData, numLocalStates);
            
            //y1, y2, x1, x2
            std::vector<int> roiMerged{imgData.rois[0][0], imgData.rois[0][1], imgData.rois[0][2], imgData.rois[0][3]};
            
            for (int k = 1; k < imgData.rois.size(); ++k) {
                roiMerged[0] = std::min(roiMerged[0], imgData.rois[k][0]);
                roiMerged[1] = std::max(roiMerged[1], imgData.rois[k][1]);
                roiMerged[2] = std::min(roiMerged[2], imgData.rois[k][2]);
                roiMerged[3] = std::max(roiMerged[3], imgData.rois[k][3]);
            }
            
            for (int k = 0; k < imgData.rois.size(); ++k) {
                imgData.rois[k][0] -= roiMerged[0];
                imgData.rois[k][1] -= roiMerged[0];
                imgData.rois[k][2] -= roiMerged[2];
                imgData.rois[k][3] -= roiMerged[2];
            }
            
            int W = roiMerged[3] - roiMerged[2];
            int H = roiMerged[1] - roiMerged[0];
            
            //aggregate probability distribution and
            Eigen::Matrix<float, Dynamic, Dynamic, RowMajor> globalBinaryProb;
            Eigen::Matrix<int, Dynamic, Dynamic, RowMajor> globalBinaryProbMask;
            ComputeGlobalBinaryProb(globalBinaryProb, globalBinaryProbMask, W, H, imgData, options.df);

	    /*cimg_library::CImg<int> tmp(globalBinaryProbMask.data(), W, H, 1, 1, true);
	    std::string tmp_filename = "/u/zzhang/CVPR16/Results/Ziyu/ForegroundMasks/"+iter->first+".png";
	    tmp.save(tmp_filename.c_str());
	    continue;*/
            
            std::vector<std::vector<int> > connCompMembers;
            std::vector<int> maxY, minY;
            ComputeConnectedComponent(connCompMembers, maxY, minY, globalBinaryProbMask.data(), W, H);
            
            // read in image and crop the bottom part
            std::string imgFile(IMAGE_FOLDER);
            imgFile.append(DELIM_FOLDER);
            imgFile.append(iter->first);
            imgFile.append(".png");
            cimg_library::CImg<unsigned char> img(imgFile.c_str());
            img.crop(roiMerged[2], roiMerged[0], roiMerged[3], roiMerged[1]);
            
            DenseCRF2D crf(W, H, numGlobalStates);
            
            MatrixXf unary = MatrixXf::Zero(numGlobalStates, W*H);
            //unary.block(0, 0, numLocalStates, W*H) = -imgData.probs[0].unaryExpr([](float x) {return std::log(x);});
            /*for (int k = 0; k < unary.rows(); ++k) {
             unary.row(k) = MatrixXf::Constant(1, W*H, std::sqrt(k));
             }*/
            /*for (int j = 0; j < H; ++j) {
             for (int i = 0; i < W; ++i) {
             for (int k = 0; k < numGlobalStates; ++k) {
             unary(k, i + j*W) = - 4.0 * std::exp(- (k-(numGlobalStates-1)*(H-1-j)/(float)(H-1)) * (k-(numGlobalStates-1)*(H-1-j)/(float)(H-1)) / (2*50));
             }
             }
             }*/
            crf.setUnaryEnergy(unary);
            
            std::vector<Eigen::MatrixXf> Compatibilities(4, Eigen::MatrixXf::Zero(numGlobalStates, numGlobalStates));
            /*for (int k = 0; k < numGlobalStates; ++k) {
             Compatibilities[0].block(k, k, 1, numGlobalStates-k) = Eigen::MatrixXf::Constant(1, numGlobalStates-k, 1.0);
             }*/
            Compatibilities[0] <<    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
	      -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,
	      -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,
	      -1, -1, -1,  0,  0,  0,  0,  0,  0,  0,
	      -1, -1, -1, -1,  0,  0,  0,  0,  0,  0,
	      -1, -1, -1, -1, -1,  0,  0,  0,  0,  0,
	      -1, -1, -1, -1, -1, -1,  0,  0,  0,  0,
	      -1, -1, -1, -1, -1, -1, -1,  0,  0,  0,
	      -1, -1, -1, -1, -1, -1, -1, -1,  0,  0,
	      -1, -1, -1, -1, -1, -1, -1, -1, -1,  0;
            Compatibilities[1] = Compatibilities[0].transpose();
            
            // read patch sizes
            std::vector<int> sizes;
            int small, medium, large;
            for (int k = 0; k < imgData.rois.size(); k++) {
                int width = imgData.rois[k][1] - imgData.rois[k][0];
                if (std::find(sizes.begin(), sizes.end(), width) == sizes.end())
                    sizes.push_back(width);
            }
            std::sort(sizes.begin(), sizes.end());
            if (sizes.size() != 3) {
                std::cout << "unexpected patch sizes" << std::endl;
                exit(-1);
            }
            small = sizes[0];
            medium = sizes[1];
            large = sizes[2];

            std::cout << "Number of patches to add potential with: " << imgData.rois.size() << std::endl;
            for (int k = 0; k < imgData.rois.size(); ++k) {
                float coef;
                if (imgData.rois[k][1] - imgData.rois[k][0] == large) {
                    coef = options.wl;
                } else if (imgData.rois[k][1] - imgData.rois[k][0] == medium) {
                    coef = options.wm;
                } else if (imgData.rois[k][1] - imgData.rois[k][0] == small) {
                    coef = options.ws;
                } else {
                    std::cout << "Patch size does not match expectation." << std::endl;
                    exit(-1);
                }
                if (coef == 0.0f) {
                    std::cout << "Skipping patch potential due to coef=0" << std::endl;
                } else {
                    crf.addPairwiseLocal(0, options.sp, imgData.probs[k], new PottsCompatibility(coef), imgData.rois[k], DIAG_KERNEL, NORMALIZE_AFTER);
                    for (int t = 1; t <= 2; ++t) {
                        crf.addPairwiseLocal(t, options.sp, imgData.probs[k], new MatrixCompatibility(coef*Compatibilities[1]), imgData.rois[k], DIAG_KERNEL, NORMALIZE_AFTER);
                        crf.addPairwiseLocal(-t, options.sp, imgData.probs[k], new MatrixCompatibility(coef*Compatibilities[0]), imgData.rois[k], DIAG_KERNEL, NORMALIZE_AFTER);
                    }
                }
                if (options.wlocc == 0.0f) {
                    std::cout << "Skipping Local Patch Prediction Smoothness Potential due to Coef=0" << std::endl;
                } else {
                    crf.addLocalPairwiseBilateral(options.slocl/*80.0*/, options.slocl/*80.0*/, options.slocpr/*13.0/255*/, imgData.probs[k], new PottsCompatibility(options.wlocc), imgData.rois[k]);
                }
            }            
            
            for (int i = 0; i < int(connCompMembers.size()) - 1; ++i) {
                for (int j = i + 1; j < int(connCompMembers.size()); ++j) {
                    if(options.wi==0.0f) {
		      std::cout << "Skipping inter-instance potential due to wi=0" << std::endl;
                    } else {
                        crf.addPairwiseInstance(new PottsCompatibility(-options.wi), connCompMembers[i], connCompMembers[j]);
                    }
                }
            }
            
            
            std::string outputFileName = options.outputFilename + iter->first;
            
            bool step = false;
            int n_iters = options.iters;
            
            std::cout << "Start inference... " << std::endl;
            if (step) {
                VectorXs map = crf.map(n_iters, step, outputFileName);
            } else {
	        VectorXs map = crf.map(n_iters, step, outputFileName);
                outputFileName += ".png";
                cimg_library::CImg<short> image(map.data(), W, H, 1, 1, true);
#ifdef WITH_MPI
                std::cout << "Saving to " << outputFileName << " by host: " << hostname << std::endl;
#else
                std::cout << "Saving to " << outputFileName << std::endl;
#endif
                image.save(outputFileName.c_str());
            }
        } catch (...) {
            std::cout << "Exception occured..." << std::endl;
            std::cout << "Currently processing: " << iter->first << std::endl;
            std::cout << "Machine: " << hostname << std::endl;
            std::cout << "ClusterID: " << ClusterID << std::endl;
            std::cout << "ClusterSize: " << ClusterSize << std::endl;
            exit(-1);
        }
    }
    
#ifdef WITH_MPI
    std::cout << "Finalizing MPI...";
    if (!MPI::Is_finalized()) {
        MPI::Finalize();
    }
    std::cout << "done" << std::endl;
#endif
    
    return 0;
}
