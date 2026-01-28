module sum_of_maxes (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] K,
    input [511:0] values_packed,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_N = 5'd16;
    
    // Binomial table (5D array: [16][16] elements)
    reg [31:0] binom_table [0:15][0:15];
    
    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] SORT_INIT = 4'd2;
    localparam [3:0] SORT_COMPARE = 4'd3;
    localparam [3:0] SORT_SWAP = 4'd4;
    localparam [3:0] SORT_NEXT_INDEX = 4'd5;
    localparam [3:0] SORT_NEXT_PASS = 4'd6;
    localparam [3:0] COMPUTE = 4'd7;
    localparam [3:0] REDUCE = 4'd8;
    localparam [3:0] DONE_STATE = 4'd9;
    
    reg [3:0] state, next_state;
    
    // Internal registers
    reg [31:0] data_reg [0:15];
    reg [3:0] pass_count;
    reg [3:0] index_count;
    reg [3:0] i_count;
    reg [63:0] accumulator;
    reg [63:0] product;
    reg [7:0] binom_init_i;
    reg [7:0] binom_init_j;
    reg [7:0] sort_i;
    
    // Unpack values into temporary array
    wire [31:0] data_wire [0:15];
    assign data_wire[0] = values_packed[31:0];
    assign data_wire[1] = values_packed[63:32];
    assign data_wire[2] = values_packed[95:64];
    assign data_wire[3] = values_packed[127:96];
    assign data_wire[4] = values_packed[159:128];
    assign data_wire[5] = values_packed[191:160];
    assign data_wire[6] = values_packed[223:192];
    assign data_wire[7] = values_packed[255:224];
    assign data_wire[8] = values_packed[287:256];
    assign data_wire[9] = values_packed[319:288];
    assign data_wire[10] = values_packed[351:320];
    assign data_wire[11] = values_packed[383:352];
    assign data_wire[12] = values_packed[415:384];
    assign data_wire[13] = values_packed[447:416];
    assign data_wire[14] = values_packed[479:448];
    assign data_wire[15] = values_packed[511:480];

    // State transition and datapath
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            accumulator <= 64'd0;
            product <= 64'd0;
            pass_count <= 4'd0;
            index_count <= 4'd0;
            i_count <= 4'd0;
            binom_init_i <= 8'd0;
            binom_init_j <= 8'd0;
            sort_i <= 8'd0;
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                data_reg[sort_i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize binomial table
                        binom_init_i <= 8'd0;
                        binom_init_j <= 8'd0;
                    end
                end
                
                LOAD: begin
                    // Load data into registers
                    for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                        data_reg[sort_i] <= data_wire[sort_i];
                    end
                end
                
                SORT_INIT: begin
                    pass_count <= 4'd0;
                    index_count <= 4'd0;
                end
                
                SORT_COMPARE: begin
                    if (data_reg[index_count] > data_reg[index_count + 4'd1]) begin
                        product <= {32'd0, data_reg[index_count]};
                        data_reg[index_count] <= data_reg[index_count + 4'd1];
                        data_reg[index_count + 4'd1] <= product[31:0];
                    end
                end
                
                SORT_NEXT_INDEX: begin
                    index_count <= index_count + 4'd1;
                end
                
                SORT_NEXT_PASS: begin
                    pass_count <= pass_count + 4'd1;
                    index_count <= 4'd0;
                end
                
                COMPUTE: begin
                    if (i_count < N) begin
                        if (i_count >= (K - 4'd1)) begin
                            product <= binom_table[i_count][K - 4'd1] * data_reg[i_count];
                            accumulator <= accumulator + (binom_table[i_count][K - 4'd1] * data_reg[i_count]);
                        end
                        i_count <= i_count + 4'd1;
                    end
                end
                
                REDUCE: begin
                    if (accumulator >= MOD) begin
                        accumulator <= accumulator - MOD;
                    end
                end
                
                DONE_STATE: begin
                    result <= accumulator[31:0];
                    done <= 1'b1;
                end
            endcase
            
            // Binomial table initialization
            if (state == IDLE && start) begin
                if (binom_init_i == 8'd0 && binom_init_j == 8'd0) begin
                    binom_table[0][0] <= 32'd1;
                end
                if (binom_init_i < 16) begin
                    if (binom_init_j < 16) begin
                        if (binom_init_i == 8'd0 && binom_init_j > 8'd0) begin
                            binom_table[binom_init_i][binom_init_j] <= 32'd0;
                        end else if (binom_init_j == 8'd0) begin
                            if (binom_init_i > 8'd0) begin
                                binom_table[binom_init_i][0] <= 32'd1;
                            end
                        end else if (binom_init_j > binom_init_i) begin
                            binom_table[binom_init_i][binom_init_j] <= 32'd0;
                        end else begin
                            binom_table[binom_init_i][binom_init_j] <= binom_table[binom_init_i - 8'd1][binom_init_j - 8'd1] + binom_table[binom_init_i - 8'd1][binom_init_j];
                        end
                        binom_init_j <= binom_init_j + 8'd1;
                    end else begin
                        binom_init_j <= 8'd0;
                        binom_init_i <= binom_init_i + 8'd1;
                    end
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                if (N <= 4'd1) next_state = COMPUTE;
                else next_state = SORT_INIT;
            end
            
            SORT_INIT: begin
                next_state = SORT_COMPARE;
            end
            
            SORT_COMPARE: begin
                next_state = SORT_SWAP;
            end
            
            SORT_SWAP: begin
                next_state = SORT_NEXT_INDEX;
            end
            
            SORT_NEXT_INDEX: begin
                if (index_count < (N - pass_count - 4'd1)) next_state = SORT_COMPARE;
                else next_state = SORT_NEXT_PASS;
            end
            
            SORT_NEXT_PASS: begin
                if (pass_count < N - 4'd1) next_state = SORT_COMPARE;
                else next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (i_count >= N) next_state = DONE_STATE;
                else if (i_count >= K - 4'd1) next_state = REDUCE;
                else next_state = COMPUTE;
            end
            
            REDUCE: begin
                if (accumulator >= MOD) next_state = REDUCE;
                else begin
                    if (i_count >= N) next_state = DONE_STATE;
                    else next_state = COMPUTE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule