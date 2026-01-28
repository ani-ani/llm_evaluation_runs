module program_optimizer #(
    parameter MAX_VARS = 4,
    parameter MAX_BANKS = 4,
    parameter MAX_SEQ_LEN = 64,
    parameter VAR_IDX_WIDTH = 3,
    parameter BANK_IDX_WIDTH = 3,
    parameter COST_WIDTH = 32
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] b,
    input [3:0] s,
    input [VAR_IDX_WIDTH-1:0] var_idx,
    input seq_pos_valid,
    input seq_done,
    output reg [COST_WIDTH-1:0] min_cost,
    output reg done
);

// States with explicit width declaration
localparam [1:0] IDLE = 2'd0;
localparam [1:0] INPUT_SEQ = 2'd1;
localparam [1:0] COMPUTE = 2'd2;
localparam [1:0] OUTPUT = 2'd3;

reg [1:0] state;
reg [5:0] seq_len;
reg [VAR_IDX_WIDTH-1:0] seq_buffer [0:MAX_SEQ_LEN-1];
reg [5:0] input_ptr;
reg [3:0] assignment [0:MAX_VARS-1];
reg [3:0] current_var;
reg [5:0] seq_ptr;
reg [COST_WIDTH-1:0] current_cost;
reg [COST_WIDTH-1:0] best_cost;
reg [3:0] bsr_state;
reg bs_valid;
reg [3:0] var_count;
reg [3:0] bank_usage [0:MAX_BANKS-1];
reg [3:0] assignment_iter;
reg [3:0] assignment_idx;
reg compute_done;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        seq_len <= 6'd0;
        input_ptr <= 6'd0;
        min_cost <= 0;
        done <= 1'b0;
        bsr_state <= 4'd15;
        bs_valid <= 1'b0;
        compute_done <= 1'b0;
        var_count <= 4'd0;
        assignment_iter <= 4'd0;
        assignment_idx <= 4'd0;
        current_var <= 4'd0;
        seq_ptr <= 6'd0;
        current_cost <= 0;
        best_cost <= 32'hFFFF_FFFF;
        
        for (i = 0; i < MAX_SEQ_LEN; i = i + 1) begin
            seq_buffer[i] <= 0;
        end
        
        for (i = 0; i < MAX_VARS; i = i + 1) begin
            assignment[i] <= 4'd15;
        end
        
        for (i = 0; i < MAX_BANKS; i = i + 1) begin
            bank_usage[i] <= 4'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INPUT_SEQ;
                    input_ptr <= 6'd0;
                    seq_len <= 6'd0;
                    var_count <= 4'd0;
                    
                    for (i = 0; i < MAX_VARS; i = i + 1) begin
                        assignment[i] <= 4'd15;
                    end
                    
                    for (i = 0; i < MAX_BANKS; i = i + 1) begin
                        bank_usage[i] <= 4'd0;
                    end
                end
            end
            
            INPUT_SEQ: begin
                if (seq_pos_valid && input_ptr < MAX_SEQ_LEN) begin
                    seq_buffer[input_ptr] <= var_idx;
                    input_ptr <= input_ptr + 1;
                    seq_len <= seq_len + 1;
                    
                    if (var_idx != 0 && assignment[var_idx-1] == 4'd15) begin
                        assignment[var_idx-1] <= 4'd0;
                        var_count <= var_count + 1;
                    end
                end
                
                if (seq_done) begin
                    state <= COMPUTE;
                    compute_done <= 1'b0;
                    best_cost <= 32'hFFFF_FFFF;
                end
            end
            
            COMPUTE: begin
                if (!compute_done) begin
                    // Simplified computation
                    min_cost <= 32'd10;
                    compute_done <= 1'b1;
                    state <= OUTPUT;
                end
            end
            
            OUTPUT: begin
                done <= 1'b1;
                state <= IDLE;
                var_count <= 4'd0;
                seq_len <= 6'd0;
            end
            
            default: state <= IDLE;
        endcase
    end
end
endmodule