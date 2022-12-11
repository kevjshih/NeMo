# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import os
import tempfile

import pytest
from omegaconf import OmegaConf

from nemo.collections.tts.models import FastPitchModel, HifiGanModel, RadTTSModel
from nemo.utils.app_state import AppState


@pytest.fixture()
def fastpitch_model():
    model = FastPitchModel.from_pretrained(model_name="tts_en_fastpitch")
    return model


@pytest.fixture()
def hifigan_model():
    model = HifiGanModel.from_pretrained(model_name="tts_hifigan")
    return model


@pytest.fixture()
def radtts_model():
    this_test_dir = os.path.dirname(os.path.abspath(__file__))

    cfg = OmegaConf.load(os.path.join(this_test_dir, '../../../examples/tts/conf/rad-tts_feature_pred.yaml'))
    cfg.model.init_from_ptl_ckpt = None
    cfg.model.train_ds.dataset.manifest_filepath = "dummy.json"
    cfg.model.train_ds.dataset.sup_data_path = "dummy.json"
    cfg.model.validation_ds.dataset.manifest_filepath = "dummy.json"
    cfg.model.validation_ds.dataset.sup_data_path = "dummy.json"
    cfg.pitch_mean = 212.35
    cfg.pitch_std = 68.52

    app_state = AppState()
    app_state.is_model_being_restored = True
    model = RadTTSModel(cfg=cfg.model)
    app_state.is_model_being_restored = False
    model.eval()
    return model


class TestExportable:
    @pytest.mark.run_only_on('GPU')
    @pytest.mark.unit
    def test_FastPitchModel_export_to_onnx(self, fastpitch_model):
        model = fastpitch_model.cuda()
        with tempfile.TemporaryDirectory() as tmpdir:
            filename = os.path.join(tmpdir, 'fp.onnx')
            model.export(output=filename, verbose=True, check_trace=True)

    @pytest.mark.with_downloads()
    @pytest.mark.run_only_on('GPU')
    @pytest.mark.unit
    def test_HifiGanModel_export_to_onnx(self, hifigan_model):
        model = hifigan_model.cuda()
        assert hifigan_model.generator is not None
        with tempfile.TemporaryDirectory() as tmpdir:
            filename = os.path.join(tmpdir, 'hfg.pt')
            model.export(output=filename, verbose=True, check_trace=True)

<<<<<<< HEAD
=======
    @pytest.mark.pleasefixme
>>>>>>> origin/main
    @pytest.mark.run_only_on('GPU')
    @pytest.mark.unit
    def test_RadTTSModel_export_to_torchscript(self, radtts_model):
        model = radtts_model.cuda()
        with tempfile.TemporaryDirectory() as tmpdir:
            filename = os.path.join(tmpdir, 'rad.ts')
<<<<<<< HEAD
            with torch.cuda.amp.autocast(enabled=True):
                model.export(output=filename, verbose=True, check_trace=True)
=======
            model.export(output=filename, verbose=True, check_trace=True)
>>>>>>> origin/main
