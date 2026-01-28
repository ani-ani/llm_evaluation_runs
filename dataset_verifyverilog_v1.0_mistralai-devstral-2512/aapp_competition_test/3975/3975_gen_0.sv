module circuit_evaluator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_en,
    input wire [3:0] config_addr,
    input wire [7:0] config_data,
    input wire [7:0] input_values,
    output reg [7:0] sensitivity,
    output reg result,
    output reg done
);

    // Node storage
    reg [7:0] values [0:15];
    reg [1:0] type [0:15];
    reg [3:0] src_a [0:15];
    reg [3:0] src_b [0:15];
    reg is_input [0:15];

    // State machine
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_CONFIG = 3'd1;
    localparam [2:0] STAGE1 = 3'd2;
    localparam [2:0] STAGE2 = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Configuration counter
    reg [5:0] config_index;

    // Sensitivity array
    reg sensitivity_reg [0:15];

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            config_index <= 6'd0;
            
            // Initialize all registers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                values[i] <= 8'd0;
                type[i] <= 2'd0;
                src_a[i] <= 4'd0;
                src_b[i] <= 4'd0;
                is_input[i] <= 1'b0;
                sensitivity_reg[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_CONFIG;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_CONFIG: begin
                    if (config_en) begin
                        if (config_addr < 4'd16) begin
                            // Load src_a and src_b
                            src_a[config_addr] <= config_data[3:0];
                            src_b[config_addr] <= config_data[7:4];
                        end else if (config_addr < 4'd32) begin
                            // Load type and is_input
                            type[config_addr - 4'd16] <= config_data[1:0];
                            is_input[config_addr - 4'd16] <= config_data[2];
                        end
                        
                        config_index <= config_index + 6'd1;
                        if (config_index == 6'd31) begin
                            next_state <= STAGE1;
                        end else begin
                            next_state <= LOAD_CONFIG;
                        end
                    end else begin
                        next_state <= LOAD_CONFIG;
                    end
                end

                STAGE1: begin
                    // Base evaluation
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (is_input[i]) begin
                            values[i] <= input_values[i];
                        end else begin
                            case (type[i])
                                2'd0: // AND
                                    values[i] <= values[src_a[i]] & values[src_b[i]];
                                2'd1: // OR
                                    values[i] <= values[src_a[i]] | values[src_b[i]];
                                2'd2: // XOR
                                    values[i] <= values[src_a[i]] ^ values[src_b[i]];
                                2'd3: // NOT
                                    values[i] <= ~values[src_a[i]];
                                default:
                                    values[i] <= 8'd0;
                            endcase
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd15) begin
                        next_state <= STAGE2;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= STAGE1;
                    end
                end

                STAGE2: begin
                    // Sensitivity propagation
                    integer i;
                    
                    // Initialize sensitivity for root (node 0)
                    sensitivity_reg[0] <= 1'b1;
                    
                    // Propagate sensitivity
                    for (i = 0; i < 16; i = i + 1) begin
                        if (sensitivity_reg[i]) begin
                            case (type[i])
                                2'd0: // AND
                                    sensitivity_reg[src_a[i]] <= sensitivity_reg[src_a[i]] | (values[src_b[i]] & 1'b1);
                                    sensitivity_reg[src_b[i]] <= sensitivity_reg[src_b[i]] | (values[src_a[i]] & 1'b1);
                                2'd1: // OR
                                    sensitivity_reg[src_a[i]] <= sensitivity_reg[src_a[i]] | (~values[src_b[i]] & 1'b1);
                                    sensitivity_reg[src_b[i]] <= sensitivity_reg[src_b[i]] | (~values[src_a[i]] & 1'b1);
                                2'd2: // XOR
                                    sensitivity_reg[src_a[i]] <= 1'b1;
                                    sensitivity_reg[src_b[i]] <= 1'b1;
                                2'd3: // NOT
                                    sensitivity_reg[src_a[i]] <= 1'b1;
                                default:
                                    ;
                            endcase
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd15) begin
                        next_state <= DONE_STATE;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= STAGE2;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= values[0];
                    
                    // Output sensitivity for inputs (nodes 8-15)
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        sensitivity[i] <= sensitivity_reg[i + 8];
                    end
                    
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule