module rescale_unit (
    input clk,
    input rst_n,
    input start,
    input [15:0] data_in,
    input [2:0] len,
    output reg [15:0] data_out,
    output reg out_valid,
    output reg done
);

// State definitions
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] COLLECT  = 3'd1;
localparam [2:0] COMPUTE  = 3'd2;
localparam [2:0] OUTPUT   = 3'd3;
localparam [2:0] DONE     = 3'd4;
localparam [2:0] WAIT_OUT = 3'd5;

// Internal registers
reg [2:0] state, next_state;
reg [2:0] count, next_count;
reg [2:0] output_count, next_output_count;
reg [15:0] min_val, next_min_val;
reg [15:0] max_val, next_max_val;
reg [15:0] scale_factor, next_scale_factor;
reg [4:0] latency_counter, next_latency_counter;

// Temporary calculation registers
reg [31:0] temp_val, next_temp_val;
reg [31:0] temp_diff, next_temp_diff;
reg [31:0] temp_mult, next_temp_mult;
reg [4:0] div_counter, next_div_counter;
reg [31:0] div_remainder, next_div_remainder;

// Synchronous logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        count <= 3'd0;
        output_count <= 3'd0;
        min_val <= 16'h7FFF;
        max_val <= 16'h8000;
        scale_factor <= 16'd0;
        latency_counter <= 5'd0;
        temp_val <= 32'd0;
        temp_diff <= 32'd0;
        temp_mult <= 32'd0;
        div_counter <= 5'd0;
        div_remainder <= 32'd0;
        data_out <= 16'd0;
        out_valid <= 1'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        count <= next_count;
        output_count <= next_output_count;
        min_val <= next_min_val;
        max_val <= next_max_val;
        scale_factor <= next_scale_factor;
        latency_counter <= next_latency_counter;
        temp_val <= next_temp_val;
        temp_diff <= next_temp_diff;
        temp_mult <= next_temp_mult;
        div_counter <= next_div_counter;
        div_remainder <= next_div_remainder;
        data_out <= data_out;
        out_valid <= out_valid;
        done <= done;
        
        case (state)
            IDLE: begin
                out_valid <= 1'b0;
                done <= 1'b0;
            end
            
            COLLECT: begin
                if (data_in < min_val) min_val <= data_in;
                if (data_in > max_val) max_val <= data_in;
            end
            
            COMPUTE: begin
                // Calculate scale = 65536 / (max - min)
                // Using simple division by repeated subtraction
                if (div_counter == 5'd0) begin
                    temp_diff <= {16'd0, max_val} - {16'd0, min_val};
                end else if (div_counter < 17) begin
                    if (div_remainder >= temp_diff) begin
                        div_remainder <= div_remainder - temp_diff;
                        scale_factor <= scale_factor + 16'd1;
                    end
                end
            end
            
            OUTPUT: begin
                out_valid <= 1'b1;
                // Calculate (val - min) * scale / 65536
                // Intermediate: ((val - min) * scale) >> 16
                data_out <= temp_mult[31:16];
            end
            
            DONE: begin
                done <= 1'b1;
                out_valid <= 1'b0;
            end
            
            WAIT_OUT: begin
                // Wait for output latency
                if (latency_counter == 5'd0) begin
                    done <= 1'b1;
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Combinational next state logic
always @(*) begin
    next_state = state;
    next_count = count;
    next_output_count = output_count;
    next_min_val = min_val;
    next_max_val = max_val;
    next_scale_factor = scale_factor;
    next_latency_counter = latency_counter;
    next_temp_val = temp_val;
    next_temp_diff = temp_diff;
    next_temp_mult = temp_mult;
    next_div_counter = div_counter;
    next_div_remainder = div_remainder;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = COLLECT;
                next_count = 3'd1;
                next_min_val = data_in;
                next_max_val = data_in;
                next_scale_factor = 16'd0;
            end
        end
        
        COLLECT: begin
            if (count < len) begin
                next_count = count + 3'd1;
            end else begin
                next_state = COMPUTE;
                next_count = 3'd0;
                next_div_counter = 5'd0;
                next_div_remainder = 32'd65536;
                next_scale_factor = 16'd0;
            end
        end
        
        COMPUTE: begin
            if (div_counter < 17) begin
                next_div_counter = div_counter + 5'd1;
            end else begin
                next_state = OUTPUT;
                next_output_count = 3'd0;
                next_temp_val = {16'd0, min_val};
            end
        end
        
        OUTPUT: begin
            if (output_count < len) begin
                next_temp_val = {16'd0, data_in};
                next_temp_mult = (temp_val - {16'd0, min_val}) * scale_factor;
                next_output_count = output_count + 3'd1;
                next_state = WAIT_OUT;
                next_latency_counter = 5'd10;
            end else begin
                next_state = DONE;
            end
        end
        
        WAIT_OUT: begin
            next_latency_counter = latency_counter - 5'd1;
            if (latency_counter == 5'd1) begin
                next_state = OUTPUT;
                next_temp_val = {16'd0, data_in};
            end
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule