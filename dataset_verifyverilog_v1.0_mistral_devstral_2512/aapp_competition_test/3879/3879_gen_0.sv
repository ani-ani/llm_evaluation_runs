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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_CORE = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] FINISHED = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] index;
    reg [31:0] current_num;
    reg [31:0] reference_core;
    reg core_valid;
    reg compare_result;
    reg [31:0] core;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for core computation
    always @(*) begin
        reg [31:0] temp_num = current_num;
        reg [31:0] temp_core = temp_num;
        
        // Remove factors of 2
        if (temp_num != 0) begin
            while (temp_core % 2 == 0 && temp_core != 0) begin
                temp_core = temp_core >> 1;
            end
            // Remove factors of 3
            while (temp_core % 3 == 0 && temp_core != 0) begin
                temp_core = temp_core / 3;
            end
        end
        core = temp_core;
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 0;
            current_num <= 0;
            reference_core <= 0;
            core_valid <= 0;
            compare_result <= 1;
            result <= 0;
            done <= 0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        index <= 0;
                        core_valid <= 0;
                        compare_result <= 1;
                        result <= 0;
                        done <= 0;
                        cycle_count <= 8'd0;
                    end
                end
                
                COMPUTE_CORE: begin
                    // Get current number based on index
                    case (index)
                        0: current_num <= arr_0;
                        1: current_num <= arr_1;
                        2: current_num <= arr_2;
                        3: current_num <= arr_3;
                        4: current_num <= arr_4;
                        5: current_num <= arr_5;
                        6: current_num <= arr_6;
                        7: current_num <= arr_7;
                    endcase
                    core_valid <= 1;
                end
                
                COMPARE: begin
                    if (core_valid) begin
                        if (index == 0) begin
                            reference_core <= core;
                        end else begin
                            if (core != reference_core) begin
                                compare_result <= 0;
                            end
                        end
                        index <= index + 1;
                        core_valid <= 0;
                    end
                end
                
                FINISHED: begin
                    result <= compare_result;
                    done <= 1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && len > 0) begin
                    next_state = COMPUTE_CORE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE_CORE: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                if (index < len && compare_result && cycle_count < MAX_CYCLES) begin
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

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state == COMPARE) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

endmodule