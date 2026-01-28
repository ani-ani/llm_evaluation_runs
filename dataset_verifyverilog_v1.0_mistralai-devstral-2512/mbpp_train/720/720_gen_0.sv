module TupleDictConcatenate(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] tuple_in [0:3],
    input wire [7:0] dict_keys [0:2],
    input wire [7:0] dict_vals [0:2],
    output reg [15:0] result [0:4],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Pipeline registers
    reg [15:0] pipe_reg0 [0:4];
    reg [15:0] pipe_reg1 [0:4];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all result registers
            result[0] <= 16'd0;
            result[1] <= 16'd0;
            result[2] <= 16'd0;
            result[3] <= 16'd0;
            result[4] <= 16'd0;
            
            // Initialize pipeline registers
            pipe_reg0[0] <= 16'd0;
            pipe_reg0[1] <= 16'd0;
            pipe_reg0[2] <= 16'd0;
            pipe_reg0[3] <= 16'd0;
            pipe_reg0[4] <= 16'd0;
            
            pipe_reg1[0] <= 16'd0;
            pipe_reg1[1] <= 16'd0;
            pipe_reg1[2] <= 16'd0;
            pipe_reg1[3] <= 16'd0;
            pipe_reg1[4] <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Pipeline stage 0: Direct tuple concatenation
                    pipe_reg0[0] <= tuple_in[0];
                    pipe_reg0[1] <= tuple_in[1];
                    pipe_reg0[2] <= tuple_in[2];
                    pipe_reg0[3] <= tuple_in[3];
                    
                    // Pipeline stage 1: Pack dictionary
                    // Format: key0[7:0], val0[7:0], key1[7:0], val1[7:0]
                    pipe_reg1[4] <= {dict_keys[1], dict_vals[1], dict_keys[0], dict_vals[0]};
                    
                    // Pipeline stage 2: Output
                    result[0] <= pipe_reg0[0];
                    result[1] <= pipe_reg0[1];
                    result[2] <= pipe_reg0[2];
                    result[3] <= pipe_reg0[3];
                    result[4] <= pipe_reg1[4];
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES - 8'd2) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= PROCESS;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule