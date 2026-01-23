module widget_packing(
    input clk,
    input rst_n,
    input start,
    input [15:0] N,
    output reg [15:0] min_empty,
    output reg done
);

    // State encoding
    localparam IDLE = 2'd0;
    localparam SEARCH = 2'd1;
    localparam COMPARE = 2'd2;
    localparam DONE = 2'd3;

    // State registers
    reg [1:0] state, next_state;
    
    // Counter registers
    reg [7:0] H, next_H;
    reg [7:0] W, next_W;
    
    // Best tracking registers
    reg [15:0] min_empty_reg, next_min_empty;
    
    // Combinational signals
    reg [7:0] W_min, W_max;
    reg [15:0] area;
    reg [15:0] empty;
    reg area_valid;
    reg empty_lt_min;
    
    // State register and synchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            H <= 8'd0;
            W <= 8'd0;
            min_empty_reg <= 16'd65535;
        end else begin
            state <= next_state;
            H <= next_H;
            W <= next_W;
            min_empty_reg <= next_min_empty;
        end
    end
    
    // Combinational logic for W_min, W_max, area, and comparison
    always @(*) begin
        // Default assignments
        next_state = state;
        next_H = H;
        next_W = W;
        next_min_empty = min_empty_reg;
        
        // Calculate W_min and W_max based on current H
        W_min = (H + 1) >> 1; // ceil(H/2) = (H+1)/2
        W_max = (H << 1);     // 2*H
        if (W_max > 8'd256)
            W_max = 8'd256;
        
        // Calculate area and empty
        area = W * H;
        empty = area - N;
        
        // Check if area >= N and empty < min_empty_reg
        area_valid = (area >= N);
        empty_lt_min = (empty < min_empty_reg);
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    next_H = 8'd1;
                    next_W = 8'd1; // Will be corrected in SEARCH state
                    next_min_empty = 16'd65535;
                end
            end
            
            SEARCH: begin
                // Compute W_min for current H
                W_min = (H + 1) >> 1;
                W_max = (H << 1);
                if (W_max > 8'd256)
                    W_max = 8'd256;
                
                // If W is out of range for this H, move to next H
                if (W < W_min) begin
                    next_W = W_min;
                end else if (W > W_max) begin
                    // Done with this H, move to next H
                    if (H == 8'd256) begin
                        next_state = DONE;
                    end else begin
                        next_H = H + 8'd1;
                        next_W = (H + 8'd1 + 8'd1) >> 1; // W_min for new H
                    end
                end else begin
                    // Valid W, go to compare
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // Check if current (W,H) is valid and better
                W_min = (H + 1) >> 1;
                W_max = (H << 1);
                if (W_max > 8'd256)
                    W_max = 8'd256;
                
                area = W * H;
                area_valid = (area >= N);
                empty = area - N;
                empty_lt_min = (empty < min_empty_reg);
                
                if (area_valid && empty_lt_min) begin
                    next_min_empty = empty;
                end
                
                // Increment W
                if (W == 8'd256) begin
                    // Max W, go to next H
                    if (H == 8'd256) begin
                        next_state = DONE;
                    end else begin
                        next_H = H + 8'd1;
                        next_W = (H + 8'd2 + 8'd1) >> 1; // W_min for H+1
                        next_state = SEARCH;
                    end
                end else begin
                    next_W = W + 8'd1;
                    next_state = SEARCH;
                end
            end
            
            DONE: begin
                // Keep outputs stable
                next_state = DONE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_empty <= 16'd0;
            done <= 1'b0;
        end else begin
            if (state == DONE) begin
                min_empty <= min_empty_reg;
                done <= 1'b1;
            end else if (state == IDLE) begin
                done <= 1'b0;
                min_empty <= 16'd0;
            end
        end
    end

endmodule