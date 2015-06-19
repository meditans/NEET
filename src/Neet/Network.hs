{-
Copyright (C) 2015 Leon Medvinsky

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
-}

{-|
Module      : Neet.Network
Description : Networks produced from NEAT Genomes
Copyright   : (c) Leon Medvinsky, 2015

License     : GPL-3
Maintainer  : lmedvinsky@hotmail.com
Stability   : experimental
Portability : ghc
-}

{-# LANGUAGE RecordWildCards #-}
module Neet.Network (
                      -- * Sigmoid
                      modSig
                      -- * Network
                    , Network(..)
                      -- ** Neuron
                    , Neuron(..)
                      -- ** Construction
                    , mkPhenotype
                      -- ** Updates
                    , stepNeuron
                    , stepNetwork
                    ) where

import Data.Map (Map)
import qualified Data.Map as M
import Data.List (foldl')

import Neet.Genome


-- | Modified sigmoid function from the original NEAT paper
modSig :: Double -> Double
modSig d = 1 / (1 + exp (-4.9 * d))


-- | A single neuron
data Neuron =
  Neuron { activation  :: Double            -- ^ The current activation
         , connections :: Map NodeId Double -- ^ The inputs to this Neuron
         , yHint       :: Rational          -- ^ Visualization height
         }
  deriving (Show)
           

-- | Sparse recurrent network, like those made by NEAT
data Network =
  Network { netInputs   :: [NodeId] -- ^ Which nodes are inputs
          , netOutputs  :: [NodeId] -- ^ Which nodes are outputs
          , netState    :: Map NodeId Neuron
          } 
  deriving (Show)


-- | Takes the previous step's activations and current inputs and gives a
-- function to update a neuron.
stepNeuron :: Map NodeId Double -> Neuron -> Neuron
stepNeuron acts (Neuron _ conns yh) = Neuron (modSig weightedSum) conns yh
  where oneFactor nId w = (acts M.! nId) * w
        weightedSum = M.foldlWithKey' (\acc k w -> acc + oneFactor k w) 0 conns


-- | Steps a network one step. Takes the network, a map of previous activations,
-- and the current input, minus the bias.
stepNetwork :: Network -> Map NodeId Double -> [Double] -> Network
stepNetwork net@Network{..} acts ins = net { netState = newNeurons }
  where pairs = zip netInputs ins

        -- | The previous state, except updated to have new inputs
        modState = foldl' (flip $ uncurry M.insert) acts pairs

        newNeurons = M.map (stepNeuron modState) netState


mkPhenotype :: Genome -> Network
mkPhenotype Genome{..} = (M.foldl' addConn nodeHusk connGenes) { netInputs = ins, netOutputs = outs }
  where addNode n@(Network _ _ s) nId (NodeGene _ yh) =
          n { netState = M.insert nId (Neuron 0 M.empty yh) s
            }

        ins = M.keys . M.filter (\ng -> nodeType ng == Input) $ nodeGenes
        outs = M.keys . M.filter (\ng -> nodeType ng == Output) $ nodeGenes

        -- | Network without connections added
        nodeHusk = M.foldlWithKey' addNode (Network [] [] M.empty) nodeGenes

        addConn2Node nId w (Neuron a cs yh) = Neuron a (M.insert nId w cs) yh

        addConn net@Network{ netState = s } ConnGene{..}
          | not connEnabled = net
          | otherwise =
              let newS = M.adjust (addConn2Node connIn connWeight) connOut s
              in net { netState = newS }
