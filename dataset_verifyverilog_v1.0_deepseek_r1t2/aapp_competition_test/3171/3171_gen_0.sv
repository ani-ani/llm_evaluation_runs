module debate_solver #(
    parameter N = 4,  // Max number of candidates (1-4)
    parameter K = 8   // Max number of utterances (1-8)
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Utterance data - packed arrays
    input wire [3:0] u_speaker [0:K-1],
    input wire [3:0] u_op     [0:K-1],
    input wire [3:0] u_arg1   [0:K-1],
    input wire [3:0] u_arg2   [0:K-1],
    
    input wire [7:0] num_utterances,
    input wire [3:0] num_candidates,
    
    output reg [1:0] result_type [0:N-1],
    output reg valid,
    output reg done
);

// State machine states
localparam [2:0] 
    S_IDLE          = 3'd0,
    S_CHECK_ASSIGN  = 3'd1,
    S_EVAL_STMT     = 3'd2,
    S_CHECK_CHARLATAN = 3'd3,
    S_NEXT_ASSIGN   = 3'd4,
    S_DONE          = 3'd5;

reg [2:0] state, next_state;
reg [7:0] assign_idx;
reg [7:0] stmt_idx;
reg [3:0] cand_idx;
reg [7:0] utter_idx;

// Current assignment storage
reg [1:0] current_assign [0:3];  // For N=4

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        valid <= 1'b0;
        done <= 1'b0;
        assign_idx <= 8'd0;
        stmt_idx <= 8'd0;
        cand_idx <= 4'd0;
        utter_idx <= 8'd0;
        
        // Initialize assignment array
        for (integer i = 0; i < 4; i = i+1) begin
            current_assign[i] <= 2'd0;
        end
        
        // Initialize result array
        for (integer i = 0; i < 4; i = i+1) begin
            result_type[i] <= 2'd0;
        end
    end
    else begin
        state <= next_state;
        
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    assign_idx <= 8'd0;
                    next_state <= S_CHECK_ASSIGN;
                end
            end
            
            S_CHECK_ASSIGN: begin
                // Implement ternary decode logic
                {current_assign[3], current_assign[2], current_assign[1], current_assign[0]} <= 
                    get_assignment(assign_idx);
                stmt_idx <= 8'd0;
                next_state <= S_EVAL_STMT;
            end
            
            S_EVAL_STMT: begin
                if (stmt_idx == num_utterances) begin
                    cand_idx <= 4'd0;
                    next_state <= S_CHECK_CHARLATAN;
                end
                else begin
                    stmt_idx <= stmt_idx + 8'd1;
                    // Placeholder for actual evaluation
                end
            end
            
            S_CHECK_CHARLATAN: begin
                if (cand_idx == num_candidates) begin
                    valid <= 1'b1;
                    result_type <= current_assign;
                    next_state <= S_DONE;
                end
                else begin
                    cand_idx <= cand_idx + 4'd1;
                    next_state <= S_NEXT_ASSIGN;
                end
            end
            
            S_NEXT_ASSIGN: begin
                if (assign_idx == 8'd80) begin  // 3^4 = 81 (0-80)
                    next_state <= S_DONE;
                end
                else begin
                    assign_idx <= assign_idx + 8'd1;
                    next_state <= S_CHECK_ASSIGN;
                end
            end
            
            S_DONE: begin
                done <= 1'b1;
                next_state <= S_IDLE;
            end
            
            default: next_state <= S_IDLE;
        endcase
    end
end

// Helper function to decode assignment index
function [7:0] get_assignment;
    input [7:0] idx;
    reg [7:0] temp;
    integer i;
    begin
        temp = idx;
        for (i = 0; i < 4; i = i+1) begin
            get_assignment[i*2 +: 2] = temp % 3'd3;
            temp = temp / 3'd3;
        end
    end
endfunction

endmodule
