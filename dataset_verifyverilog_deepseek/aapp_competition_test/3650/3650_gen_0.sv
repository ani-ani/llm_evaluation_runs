module sliding_blocks_check ( 
  input [1:0] init_r, init_c, 
  input [3:0][1:0] target_r, target_c, 
  input [1:0] block_count, 
  output reg possible 
); 
  
  reg [3:0] overlap; 
  reg [3:0] clear_left, clear_right, clear_up, clear_down; 
  reg [3:0] clear_any; 
  reg [3:0] connected, stage1_connected, stage2_connected; 
  reg all_connected; 
  integer i, j, k; 
  
  always_comb begin 
    possible = 1'b1; 
    overlap = 4'b0; 
    clear_any = 4'b0; 
    connected = 4'b0; 
    stage1_connected = 4'b0; 
    stage2_connected = 4'b0; 
    all_connected = 1'b1; 
    
    // Overlap and clear path checks
    for (i = 0; i < 4; i = i + 1) begin 
      if (i < block_count) begin 
        // Overlap with initial
        if (target_r[i] == init_r &amp;&amp; target_c[i] == init_c) 
          possible = 1'b0; 
        
        // Clear direction checks
        clear_left[i] = 1'b1; 
        clear_right[i] = 1'b1; 
        clear_up[i] = 1'b1; 
        clear_down[i] = 1'b1; 
        
        // Check initial block obstruction
        if (target_r[i] == init_r) begin 
          if (init_c < target_c[i]) clear_left[i] = 1'b0; 
          if (init_c > target_c[i]) clear_right[i] = 1'b0; 
        end 
        if (target_c[i] == init_c) begin 
          if (init_r < target_r[i]) clear_up[i] = 1'b0; 
          if (init_r > target_r[i]) clear_down[i] = 1'b0; 
        end 
        
        // Check other targets obstruction
        for (j = 0; j < 4; j = j + 1) begin 
          if (j != i &amp;&amp; j < block_count) begin 
            if (target_r[j] == target_r[i]) begin 
              if (target_c[j] < target_c[i]) clear_left[i] = 1'b0; 
              if (target_c[j] > target_c[i]) clear_right[i] = 1'b0; 
            end 
            if (target_c[j] == target_c[i]) begin 
              if (target_r[j] < target_r[i]) clear_up[i] = 1'b0; 
              if (target_r[j] > target_r[i]) clear_down[i] = 1'b0; 
            end 
          end 
        end 
        
        clear_any[i] = clear_left[i] | clear_right[i] | clear_up[i] | clear_down[i]; 
        if (!clear_any[i]) possible = 1'b0; 
      end 
    end 
    
    // Tree structure checks
    // Direct connections to initial
    for (i = 0; i < 4; i = i + 1) begin 
      if (i < block_count) begin 
        connected[i] = 1'b0; 
        if (target_r[i] == init_r) begin 
          connected[i] = 1'b1; 
          for (k = 0; k < 4; k = k + 1) begin 
            if (k != i &amp;&amp; k < block_count &amp;&amp; target_r[k] == init_r) begin 
              if ((init_c < target_c[i] &amp;&amp; target_c[k] > init_c &amp;&amp; target_c[k] < target_c[i]) || 
                  (init_c > target_c[i] &amp;&amp; target_c[k] < init_c &amp;&amp; target_c[k] > target_c[i])) 
                connected[i] = 1'b0; 
            end 
          end 
        end 
        else if (target_c[i] == init_c) begin 
          connected[i] = 1'b1; 
          for (k = 0; k < 4; k = k + 1) begin 
            if (k != i &amp;&amp; k < block_count &amp;&amp; target_c[k] == init_c) begin 
              if ((init_r < target_r[i] &amp;&amp; target_r[k] > init_r &amp;&amp; target_r[k] < target_r[i]) || 
                  (init_r > target_r[i] &amp;&amp; target_r[k] < init_r &amp;&amp; target_r[k] > target_r[i])) 
                connected[i] = 1'b0; 
            end 
          end 
        end 
      end 
    end 
    
    // Stage 1 connections
    stage1_connected = connected; 
    for (i = 0; i < 4; i = i + 1) begin 
      if (i < block_count &amp;&amp; !connected[i]) begin 
        for (j = 0; j < 4; j = j + 1) begin 
          if (j != i &amp;&amp; j < block_count &amp;&amp; connected[j]) begin 
            // Check row connection
            if (target_r[i] == target_r[j]) begin 
              stage1_connected[i] = 1'b1; 
              for (k = 0; k < 4; k = k + 1) begin 
                if (k != i &amp;&amp; k != j &amp;&amp; k < block_count &amp;&amp; target_r[k] == target_r[i]) begin 
                  if ((target_c[j] < target_c[i] &amp;&amp; target_c[k] > target_c[j] &amp;&amp; target_c[k] < target_c[i]) || 
                      (target_c[j] > target_c[i] &amp;&amp; target_c[k] < target_c[j] &amp;&amp; target_c[k] > target_c[i])) 
                    stage1_connected[i] = 1'b0; 
                end 
              end 
            end 
            // Check column connection
            else if (target_c[i] == target_c[j]) begin 
              stage1_connected[i] = 1'b1; 
              for (k = 0; k < 4; k = k + 1) begin 
                if (k != i &amp;&amp; k != j &amp;&amp; k < block_count &amp;&amp; target_c[k] == target_c[i]) begin 
                  if ((target_r[j] < target_r[i] &amp;&amp; target_r[k] > target_r[j] &amp;&amp; target_r[k] < target_r[i]) || 
                      (target_r[j] > target_r[i] &amp;&amp; target_r[k] < target_r[j] &amp;&amp; target_r[k] > target_r[i])) 
                    stage1_connected[i] = 1'b0; 
                end 
              end 
            end 
          end 
        end 
      end 
    end 
    
    // Stage 2 connections
    stage2_connected = stage1_connected; 
    for (i = 0; i < 4; i = i + 1) begin 
      if (i < block_count &amp;&amp; !stage1_connected[i]) begin 
        for (j = 0; j < 4; j = j + 1) begin 
          if (j != i &amp;&amp; j < block_count &amp;&amp; stage1_connected[j]) begin 
            // Check row connection
            if (target_r[i] == target_r[j]) begin 
              stage2_connected[i] = 1'b1; 
              for (k = 0; k < 4; k = k + 1) begin 
                if (k != i &amp;&amp; k != j &amp;&amp; k < block_count &amp;&amp; target_r[k] == target_r[i]) begin 
                  if ((target_c[j] < target_c[i] &amp;&amp; target_c[k] > target_c[j] &amp;&amp; target_c[k] < target_c[i]) || 
                      (target_c[j] > target_c[i] &amp;&amp; target_c[k] < target_c[j] &amp;&amp; target_c[k] > target_c[i])) 
                    stage2_connected[i] = 1'b0; 
                end 
              end 
            end 
            // Check column connection
            else if (target_c[i] == target_c[j]) begin 
              stage2_connected[i] = 1'b1; 
              for (k = 0; k < 4; k = k + 1) begin 
                if (k != i &amp;&amp; k != j &amp;&amp; k < block_count &amp;&amp; target_c[k] == target_c[i]) begin 
                  if ((target_r[j] < target_r[i] &amp;&amp; target_r[k] > target_r[j] &amp;&amp; target_r[k] < target_r[i]) || 
                      (target_r[j] > target_r[i] &amp;&amp; target_r[k] < target_r[j] &amp;&amp; target_r[k] > target_r[i])) 
                    stage2_connected[i] = 1'b0; 
                end 
              end 
            end 
          end 
        end 
      end 
    end 
    
    // Check if all targets are connected
    for (i = 0; i < 4; i = i + 1) begin 
      if (i < block_count &amp;&amp; !stage2_connected[i]) 
        all_connected = 1'b0; 
    end 
    
    if (!all_connected) 
      possible = 1'b0; 
  end 
endmodule