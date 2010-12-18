# Unit tests for backpropagation.rb

# The Clever Algorithms Project: http://www.CleverAlgorithms.com
# (c) Copyright 2010 Jason Brownlee. Some Rights Reserved. 
# This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 2.5 Australia License.

require "test/unit"
require "../backpropagation"

class TC_BackPropagation < Test::Unit::TestCase
  
  # test the generation of random vectors
  def test_random_vector
    bounds = [-3,3]
    minmax = Array.new(20) {bounds}
    300.times do 
      vector = random_vector(minmax)
      sum = 0.0
      assert_equal(20, vector.size)
      vector.each do |v|
        assert(v >= bounds[0])
        assert(v <= bounds[1])
        sum += v
      end
      assert_in_delta(bounds[0]+((bounds[1]-bounds[0])/2.0), sum/300.0, 0.1)
    end    
  end
  
  # test that a class can be turned into a regression problem in [0,1]
  def test_normalize_class_index
    assert_equal(0.0, normalize_class_index(0, Array.new(2)))
    assert_equal(1.0, normalize_class_index(1, Array.new(2)))
    
    assert_equal(0.0, normalize_class_index(0, Array.new(3)))    
    assert_equal(0.5, normalize_class_index(1, Array.new(3)))
    assert_equal(1.0, normalize_class_index(2, Array.new(3)))
  end
  
  # test that a value in [0,1] can be turned into a class index
  def test_denormalize_class_index
    assert_equal(0, denormalize_class_index(0.0, Array.new(2)))
    assert_equal(1, denormalize_class_index(1.0, Array.new(2)))
    assert_equal(0, denormalize_class_index(0.25, Array.new(2)))
    assert_equal(1, denormalize_class_index(0.75, Array.new(2)))
    
    assert_equal(0, denormalize_class_index(0.0, Array.new(3)))
    assert_equal(1, denormalize_class_index(0.5, Array.new(3)))
    assert_equal(2, denormalize_class_index(1.0, Array.new(3)))
  end
  
  # test the generation of random patterns
  def test_generate_random_pattern
    domain = {"A"=>[[0,1],[2,3]],"B"=>[[2,3],[4,5]]}
    500.times do
      p = generate_random_pattern(domain)
      assert(p[:class_number] == 0 || p[:class_number] == 1)
      assert(p[:class_label] == "A" || p[:class_label] == "B")
      assert(p[:class_norm] == 1 || p[:class_norm] == 0)
      assert_equal(2, p[:vector].size)
      if p[:class_label] == "A"
        assert(p[:vector][0] >= domain["A"][0][0] && p[:vector][0] <= domain["A"][0][1])
        assert(p[:vector][1] >= domain["A"][1][0] && p[:vector][1] <= domain["A"][1][1])
      else
        assert(p[:vector][0] >= domain["B"][0][0] && p[:vector][0] <= domain["B"][0][1])
        assert(p[:vector][1] >= domain["B"][1][0] && p[:vector][1] <= domain["B"][1][1])        
      end
    end
  end
  
  # test the generation of small random weights
  def test_initialize_weights
    weights = initialize_weights(100)
    # adds a bias
    assert_equal(101, weights.size)
    # check values in [-0.5,0.5]
    weights.each do |w|
      assert(w <= 0.5)
      assert(w > -0.5)
    end
  end

  # test weighted sum function
  def test_activate
    assert_equal(5.0, activate([1.0, 1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]))
    assert_equal(2.5, activate([0.5, 0.5, 0.5, 0.5, 0.5], [1.0, 1.0, 1.0, 1.0]))
  end
  
  # test the transfer function
  def test_transfer
    # small values stay smallish
    assert_in_delta(0.73, transfer(1.0), 0.01)
    assert_in_delta(0.5, transfer(0.0), 0.001)
    # large/small values get squashed
    assert_in_delta(1.0, transfer(10.0), 0.0001)
    assert_in_delta(0.0, transfer(-10.0), 0.0001)
  end
  
  # test derivative of transfer function
  def test_transfer_derivative
    assert_equal(0.0, transfer_derivative(1.0))
    assert_equal(0.0, transfer_derivative(0.0))
    assert_equal(0.25, transfer_derivative(0.5))
  end
  
  # test the forward propagation of output
  def test_forward_propagate
    n1, n2, n3 = {:weights=>[0.2,0.2,0.2]}, {:weights=>[0.3,0.3,0.3]}, {:weights=>[0.4,0.4,0.4]}
    network = [[n1,n2],[n3]]
    pattern = {:vector=>[0.1,0.1]}
    domain = {"A"=>[[0,0.4999999],[0,0.4999999]],"B"=>[[0.5,1],[0.5,1]]}
    out_actual, out_class = forward_propagate(network, pattern, domain)
    # input layer
    t1 = 0.02+0.02+0.2
    assert_equal(t1, n1[:activation])    
    assert_equal(transfer(t1), n1[:output])
    t2 = 0.03+0.03+0.3
    assert_equal(t2, n2[:activation])
    assert_equal(transfer(t2), n2[:output])
    # hidden
    t3 = (0.4*transfer(t1))+(0.4*transfer(t2))+0.4
    assert_equal(t3, n3[:activation])
    assert_equal(transfer(t3), n3[:output])
    # outputs
    assert_equal(transfer(t3), out_actual) # 0.702556520749393
    assert_equal("B", out_class)
  end
  
  # test the calculation of error signals
  def test_backward_propagate_error
    pattern = {:vector=>[0.1,0.1], :class_norm=>1.0} # B
    n1 = {:weights=>[0.2,0.2,0.2], :output=>transfer(0.02+0.02+0.2)}
    n2 = {:weights=>[0.3,0.3,0.3], :output=>transfer(0.03+0.03+0.3)}
    n3 = {:weights=>[0.4,0.4,0.4], :output=>transfer((0.4*n1[:output])+(0.4*n2[:output])+0.4)}
    network = [[n1,n2],[n3]]    
    backward_propagate_error(network, pattern)
    # output node
    e1 = (pattern[:class_norm]-n3[:output]) * transfer_derivative(n3[:output])
    assert_equal(e1, n3[:error_delta])
    # input nodes
    e2 = (0.4*e1) * transfer_derivative(n1[:output])
    assert_equal(e2, n1[:error_delta])
    e3 = (0.4*e1) * transfer_derivative(n2[:output])
    assert_equal(e3, n2[:error_delta])
  end
  
  # test the calculation of error derivatives
  def test_calculate_error_derivatives_for_weights
    pattern = {:vector=>[0.1,0.1]}
    n1 = {:weights=>[0.2,0.2,0.2], :error_delta=>0.5, :output=>transfer(0.02+0.02+0.2)}
    n2 = {:weights=>[0.3,0.3,0.3], :error_delta=>-0.6, :output=>transfer(0.03+0.03+0.3)}
    n3 = {:weights=>[0.4,0.4,0.4], :error_delta=>0.7, :output=>transfer((0.4*n1[:output])+(0.4*n2[:output])+0.4)}
    network = [[n1,n2],[n3]]    
    calculate_error_derivatives_for_weights(network, pattern)
    # TODO
  end
  
  # test that weights are updated as expected
  def test_update_weights
    n1 = {:weights=>[0.2,0.2,0.2], :error_derivative=>[0.1, -0.5, 100.0]}
    network = [[n1]]
    update_weights(network, 1.0)
    assert_equal((0.2 + (0.1*1.0)), n1[:weights][0])
    assert_equal((0.2 + (-0.5*1.0)), n1[:weights][1])
    assert_equal((0.2 + (100*1.0)), n1[:weights][2])
  end
  
end