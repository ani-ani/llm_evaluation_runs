module SubsequenceHash (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [7:0] K,
    input wire [15:0] B,
    input wire [15:0] M,
    input wire [7:0] a0,
    input wire [7:0] a1,
    input wire [7:0] a2,
    input wire [7:0] a3,
    input wire [7:0] a4,
    input wire [7:0] a5,
    input wire [7:0] a6,
    input wire [7:0] a7,
    output reg [15:0] hash,
    output reg valid,
    output reg done
);

// State parameters
localparam [2:0] STATE_IDLE           = 3'd0;
localparam [2:0] STATE_COMPUTE_MASK   = 3'd1;
localparam [2:0] STATE_COMPUTE_LOOP   = 3'd2;
localparam [2:0] STATE_SORT_OUTER     = 3'd3;
localparam [2:0] STATE_SORT_INNER     = 3'd4;
localparam [2:0] STATE_OUTPUT         = 3'd5;
localparam [2:0] STATE_DONE           = 3'd6;

reg [2:0] current_state, next_state;
reg [7:0] mask_counter;
reg [7:0] num_masks;
reg [7:0] array_elements [0:7];

reg [3:0] compute_i;
reg [15:0] temp_hash;
reg [63:0] temp_seq;

reg [7:0] sort_i;
reg [7:0] sort_j;
reg swap_flag;
reg [7:0] max_j;
reg [7:0] sort_max_j;

reg [7:0] output_counter;
reg [7:0] stored_K;

reg [63:0] temp_seq_swap;
reg [7:0] temp_mask_swap;
reg [15:0] temp_hash_swap;

reg [7:0] mask_list [0:254];
reg [15:0] hash_list [0:254];
reg [63:0] seq_list [0:254];

integer i; // Loop index for reset

// State register update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= STATE_IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        hash <= 16'd0;
        for (i=0; i<8; i=i+1)
            array_elements[i] <= 8'd0;
        for (i=0; i<255; i=i+1) begin
            mask_list[i] <= 8'd0;
            hash_list[i] <= 16'd0;
            seq_list[i] <= 64'd0;
        end
    end else begin
        current_state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        STATE_IDLE: begin
            if (start) begin
                next_state = STATE_COMPUTE_MASK;
            end
        end
        STATE_COMPUTE_MASK: begin
            next_state = STATE_COMPUTE_LOOP;
        end
        STATE_COMPUTE_LOOP: begin
            if (compute_i == N)
                next_state = mask_counter == num_masks ? STATE_SORT_OUTER : STATE_COMPUTE_MASK;
            else
                next_state = STATE_COMPUTE_LOOP;
        end
        STATE_SORT_OUTER: begin
            next_state = swap_flag ? STATE_SORT_INNER : STATE_OUTPUT;
        end
        STATE_SORT_INNER: begin
            if (sort_j == sort_max_j)
                next_state = STATE_SORT_OUTER;
            else
                next_state = STATE_SORT_INNER;
        end
        STATE_OUTPUT: begin
            if (output_counter == stored_K)
                next_state = STATE_DONE;
            else
                next_state = STATE_OUTPUT;
        end
        STATE_DONE: begin
            next_state = STATE_IDLE;
        end
    endcase
end

// State machine actions
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mask_counter <= 8'd0;
        num_masks <= 8'd0;
        compute_i <= 4'd0;
        output_counter <= 8'd0;
        stored_K <= 8'd0;
        temp_hash <= 16'd0;
        temp_seq <= 64'd0;

        sort_i <= 8'd0;
        sort_j <= 8'd0;
        swap_flag <= 1'b0;
        max_j <= 8'd0;
        sort_max_j <= 8'd0;
    
    end else begin
        case (current_state)
            STATE_IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                output_counter <= 8'd0;
                if (start) begin
                    stored_K <= (K > 8'd0) ? K : 8'd1;
                    num_masks <= (8'd1 << N) - 8'd1;
                    mask_counter <= 8'd1;
                    array_elements[0] <= a0;
                    array_elements[1] <= a1;
                    array_elements[2] <= a2;
                    array_elements[3] <= a3;
                    array_elements[4] <= a4;
                    array_elements[5] <= a5;
                    array_elements[6] <= a6;
                    array_elements[7] <= a7;
                end
            end
            
            STATE_COMPUTE_MASK: begin
                temp_hash <= 16'd0;
                temp_seq <= 64'd0;
                compute_i <= 4'd0;
            end
            
            STATE_COMPUTE_LOOP: begin
                if (compute_i < N) begin
                    if (mask_counter[compute_i]) begin
                        temp_hash <= (temp_hash * B + array_elements[compute_i]) % M;
                        temp_seq <= (temp_seq << 8) | array_elements[compute_i];
                    end
                    compute_i <= compute_i + 4'd1;
                end else begin
                    mask_list[mask_counter - 8'd1] <= mask_counter;
                    hash_list[mask_counter - 8'd1] <= temp_hash;
                    seq_list[mask_counter - 8'd1] <= temp_seq;
                    if (mask_counter != num_masks) begin
                        mask_counter <= mask_counter + 8'd1;
                    end
                end
            end
            
            STATE_SORT_OUTER: begin
                if (swap_flag || sort_i == 8'd0) begin
                    swap_flag <= 1'b0;
                    sort_j <= 8'd0;
                    max_j <= num_masks - sort_i - 8'd1;
                    sort_max_j <= num_masks - sort_i - 8'd1;
                end else begin
                    // Sorting complete
                end
                if (sort_i != 8'd0 && !swap_flag)
                    sort_i <= sort_i + 8'd1;
            end
            
            STATE_SORT_INNER: begin
                if (sort_j < sort_max_j) begin
                    if (seq_list[sort_j] > seq_list[sort_j + 8'd1]) begin
                        // Perform swap
                        temp_seq_swap = seq_list[sort_j];
                        seq_list[sort_j] <= seq_list[sort_j + 8'd1];
                        seq_list[sort_j + 8'd1] <= temp_seq_swap;
                        
                        temp_mask_swap = mask_list[sort_j];
                        mask_list[sort_j] <= mask_list[sort_j + 8'd1];
                        mask_list[sort_j + 8'd1] <= temp_mask_swap;
                        
                        temp_hash_swap = hash_list[sort_j];
                        hash_list[sort_j] <= hash_list[sort_j + 8'd1];
                        hash_list[sort_j + 8'd1] <= temp_hash_swap;
                        
                        swap_flag <= 1'b1;
                    end
                    sort_j <= sort_j + 8'd1;
                end
            end
            
            STATE_OUTPUT: begin
                valid <= 1'b0;
                if (output_counter < stored_K) begin
                    hash <= hash_list[output_counter];
                    valid <= 1'b1;
                    output_counter <= output_counter + 8'd1;
                end else begin
                    done <= 1'b1;
                end
            end
            
            STATE_DONE: begin
                done <= 1'b0;
            end
        endcase
    end
end

endmodule