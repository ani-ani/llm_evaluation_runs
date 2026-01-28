module min_extensions(
    input clk,
    input rst_n,
    input start,
    input [15:0] a_i,
    input [15:0] b_i,
    input [15:0] h_i,
    input [15:0] w_i,
    input [3:0] n_i,
    input [15:0] mult_i,
    input mult_valid,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_MULTS = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Multiplier storage
    reg [15:0] multipliers [0:15];
    reg [3:0] mult_count;
    
    // BFS queue (ping-pong buffers)
    reg [15:0] queue_h [0:1023];
    reg [15:0] queue_w [0:1023];
    reg [9:0] queue_head, queue_tail;
    reg [9:0] next_queue_head, next_queue_tail;
    reg [15:0] next_queue_h [0:1023];
    reg [15:0] next_queue_w [0:1023];
    reg queue_active;
    
    // Current state tracking
    reg [15:0] h_cur, w_cur;
    reg [7:0] extension_count;
    reg [7:0] max_extensions;
    
    // Target dimensions
    reg [15:0] target_a, target_b;
    reg [15:0] max_target;
    
    // Clamping value
    localparam [15:0] CLAMP_VALUE = 16'd65535;
    
    // Cycle counter for timeout
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd255;
            done <= 1'b0;
            busy <= 1'b0;
            mult_count <= 4'd0;
            queue_head <= 10'd0;
            queue_tail <= 10'd0;
            next_queue_head <= 10'd0;
            next_queue_tail <= 10'd0;
            queue_active <= 1'b0;
            extension_count <= 8'd0;
            max_extensions <= 8'd32;
            cycle_count <= 14'd0;
            
            // Initialize queues
            integer i;
            for (i = 0; i < 1024; i = i + 1) begin
                queue_h[i] <= 16'd0;
                queue_w[i] <= 16'd0;
                next_queue_h[i] <= 16'd0;
                next_queue_w[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD_MULTS;
                        busy <= 1'b1;
                        // Initialize target dimensions
                        target_a <= a_i;
                        target_b <= b_i;
                        max_target <= (a_i > b_i) ? a_i : b_i;
                        // Initialize multipliers
                        mult_count <= 4'd0;
                        // Check if initial dimensions already satisfy
                        if ((h_i >= target_a && w_i >= target_b) || (h_i >= target_b && w_i >= target_a)) begin
                            result <= 8'd0;
                            next_state <= DONE;
                        end
                    end
                end
                
                LOAD_MULTS: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    if (mult_valid && mult_count < n_i && mult_count < 4'd16) begin
                        multipliers[mult_count] <= mult_i;
                        mult_count <= mult_count + 4'd1;
                    end
                    if (mult_count >= n_i || mult_count >= 4'd16) begin
                        next_state <= COMPUTE;
                        // Initialize BFS
                        queue_head <= 10'd0;
                        queue_tail <= 10'd1;
                        queue_h[0] <= h_i;
                        queue_w[0] <= w_i;
                        queue_active <= 1'b0;
                        extension_count <= 8'd0;
                        max_extensions <= (n_i > 8'd32) ? 8'd32 : n_i;
                        cycle_count <= 14'd0;
                    end
                end
                
                COMPUTE: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= cycle_count + 14'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 8'd255;
                        next_state <= DONE;
                    end else begin
                        // Process current queue
                        if (queue_head < queue_tail) begin
                            h_cur <= queue_h[queue_head];
                            w_cur <= queue_w[queue_head];
                            queue_head <= queue_head + 10'd1;
                            
                            // Try applying each multiplier
                            integer k;
                            for (k = 0; k < mult_count; k = k + 1) begin
                                // Apply to height
                                if (h_cur * multipliers[k] > CLAMP_VALUE) begin
                                    h_cur <= CLAMP_VALUE;
                                end else begin
                                    h_cur <= h_cur * multipliers[k];
                                end
                                
                                // Check condition
                                if ((h_cur >= target_a && w_cur >= target_b) || (h_cur >= target_b && w_cur >= target_a)) begin
                                    result <= extension_count + 8'd1;
                                    next_state <= DONE;
                                end else begin
                                    // Add to next queue
                                    if (next_queue_tail < 1024) begin
                                        next_queue_h[next_queue_tail] <= h_cur;
                                        next_queue_w[next_queue_tail] <= w_cur;
                                        next_queue_tail <= next_queue_tail + 10'd1;
                                    end
                                end
                                
                                // Restore h_cur
                                h_cur <= queue_h[queue_head - 10'd1];
                                
                                // Apply to width
                                if (w_cur * multipliers[k] > CLAMP_VALUE) begin
                                    w_cur <= CLAMP_VALUE;
                                end else begin
                                    w_cur <= w_cur * multipliers[k];
                                end
                                
                                // Check condition
                                if ((h_cur >= target_a && w_cur >= target_b) || (h_cur >= target_b && w_cur >= target_a)) begin
                                    result <= extension_count + 8'd1;
                                    next_state <= DONE;
                                end else begin
                                    // Add to next queue
                                    if (next_queue_tail < 1024) begin
                                        next_queue_h[next_queue_tail] <= h_cur;
                                        next_queue_w[next_queue_tail] <= w_cur;
                                        next_queue_tail <= next_queue_tail + 10'd1;
                                    end
                                end
                                
                                // Restore w_cur
                                w_cur <= queue_w[queue_head - 10'd1];
                            end
                        end else begin
                            // Queue empty, check if we found solution
                            if (extension_count >= max_extensions) begin
                                result <= 8'd255;
                                next_state <= DONE;
                            end else begin
                                // Switch queues
                                queue_active <= ~queue_active;
                                if (queue_active) begin
                                    queue_head <= 10'd0;
                                    queue_tail <= next_queue_tail;
                                    for (k = 0; k < next_queue_tail; k = k + 1) begin
                                        queue_h[k] <= next_queue_h[k];
                                        queue_w[k] <= next_queue_w[k];
                                    end
                                end else begin
                                    queue_head <= 10'd0;
                                    queue_tail <= next_queue_tail;
                                    for (k = 0; k < next_queue_tail; k = k + 1) begin
                                        queue_h[k] <= next_queue_h[k];
                                        queue_w[k] <= next_queue_w[k];
                                    end
                                end
                                next_queue_tail <= 10'd0;
                                extension_count <= extension_count + 8'd1;
                            end
                        end
                    end
                end
                
                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 8'd255;
                end
            endcase
        end
    end

endmodule