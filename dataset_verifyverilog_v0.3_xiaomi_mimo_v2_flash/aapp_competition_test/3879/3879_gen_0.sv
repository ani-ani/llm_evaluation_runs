module can_make_equal(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] arr_0,
    input wire [31:0] arr_1,
    input wire [31:0] arr_2,
    input wire [31:0] arr_3,
    input wire [31:0] arr_4,
    input wire [31:0] arr_5,
    input wire [31:0] arr_6,
    input wire [31:0] arr_7,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_CORE = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] FINISHED = 3'd3;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] index;
    reg [31:0] current_num;
    reg [31:0] reference_core;
    reg core_valid;
    reg compare_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Combinational logic for core computation
    reg [31:0] temp_num;
    reg [31:0] core;
    reg [31:0] temp_val;
    
    always @(*) begin
        temp_val = current_num;
        // Remove factors of 2
        while ((temp_val & 32'h0000_0001) == 32'd0 && temp_val != 32'd0) begin
            temp_val = temp_val >> 1;
        end
        // Remove factors of 3
        while ((temp_val % 32'd3) == 32'd0 && temp_val != 32'd0) begin
            temp_val = temp_val / 32'd3;
        end
        core = temp_val;
    end
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            current_num <= 32'd0;
            reference_core <= 32'd0;
            core_valid <= 1'b0;
            compare_result <= 1'b1;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        index <= 4'd0;
                        core_valid <= 1'b0;
                        compare_result <= 1'b1;
                        result <= 1'b0;
                    end
                end
                
                COMPUTE_CORE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Get current number based on index
                    case (index)
                        4'd0: current_num <= arr_0;
                        4'd1: current_num <= arr_1;
                        4'd2: current_num <= arr_2;
                        4'd3: current_num <= arr_3;
                        4'd4: current_num <= arr_4;
                        4'd5: current_num <= arr_5;
                        4'd6: current_num <= arr_6;
                        4'd7: current_num <= arr_7;
                        default: current_num <= 32'd0;
                    endcase
                    core_valid <= 1'b1;
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (core_valid) begin
                        if (index == 4'd0) begin
                            reference_core <= core;
                        end else begin
                            if (core != reference_core) begin
                                compare_result <= 1'b0;
                            end
                        end
                        index <= index + 4'd1;
                        core_valid <= 1'b0;
                    end
                end
                
                FINISHED: begin
                    result <= compare_result;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && len > 4'd0) begin
                    next_state = COMPUTE_CORE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE_CORE: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                if ((index < len) && (compare_result == 1'b1) && (cycle_count < MAX_CYCLES)) begin
                    next_state = COMPUTE_CORE;
                end else begin
                    next_state = FINISHED;
                end
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule