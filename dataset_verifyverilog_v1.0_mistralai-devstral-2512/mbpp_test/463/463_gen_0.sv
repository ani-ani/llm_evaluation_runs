module max_product_subarray(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_0,
    input wire signed [7:0] arr_1,
    input wire signed [7:0] arr_2,
    input wire signed [7:0] arr_3,
    input wire signed [7:0] arr_4,
    input wire signed [7:0] arr_5,
    input wire signed [7:0] arr_6,
    input wire signed [7:0] arr_7,
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg signed [7:0] current_val;
    reg signed [15:0] current_max, current_min, global_max;
    reg signed [15:0] temp_max, temp_min;
    reg signed [7:0] arr_reg [0:7];
    reg [3:0] len_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            current_max <= 16'd1;
            current_min <= 16'd1;
            global_max <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = PROCESS;
            end
            PROCESS: begin
                if (index == len_reg - 4'd1) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load inputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arr_reg[0] <= 8'd0;
            arr_reg[1] <= 8'd0;
            arr_reg[2] <= 8'd0;
            arr_reg[3] <= 8'd0;
            arr_reg[4] <= 8'd0;
            arr_reg[5] <= 8'd0;
            arr_reg[6] <= 8'd0;
            arr_reg[7] <= 8'd0;
            len_reg <= 4'd0;
        end else begin
            if (state == LOAD) begin
                arr_reg[0] <= arr_0;
                arr_reg[1] <= arr_1;
                arr_reg[2] <= arr_2;
                arr_reg[3] <= arr_3;
                arr_reg[4] <= arr_4;
                arr_reg[5] <= arr_5;
                arr_reg[6] <= arr_6;
                arr_reg[7] <= arr_7;
                len_reg <= len;
                index <= 4'd0;
                current_max <= 16'd1;
                current_min <= 16'd1;
                global_max <= 16'd0;
                cycle_count <= 8'd0;
            end
        end
    end

    // Process logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_val <= 8'd0;
        end else begin
            if (state == PROCESS) begin
                current_val <= arr_reg[index];
                
                // Compute new max and min
                temp_max <= current_max * current_val;
                temp_min <= current_min * current_val;
                
                if (current_val > 8'd0) begin
                    current_max <= temp_max;
                    current_min <= temp_min;
                end else if (current_val < 8'd0) begin
                    current_max <= temp_min;
                    current_min <= temp_max;
                end else begin
                    current_max <= 16'd1;
                    current_min <= 16'd1;
                end
                
                // Update global max
                if (current_max > global_max) begin
                    global_max <= current_max;
                end
                
                // Increment index
                index <= index + 4'd1;
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Result and done logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == FINISH) begin
                if (len_reg == 4'd0) begin
                    result <= 16'd0;
                end else begin
                    result <= global_max;
                end
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (cycle_count >= MAX_CYCLES) begin
                next_state = IDLE;
                done <= 1'b1;
                result <= global_max;
            end
        end
    end

endmodule