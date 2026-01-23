module council_assignment #(
    parameter MAX_CLUBS = 4,
    parameter MAX_RESIDENTS = 4,
    parameter MAX_PARTIES = 4
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_clubs,
    input wire [3:0] num_residents,
    input wire [3:0] num_parties,
    input wire [3:0] resident_party [0:MAX_RESIDENTS-1],
    input wire [3:0] club_residents [0:MAX_CLUBS*MAX_RESIDENTS-1],
    input wire [3:0] club_size [0:MAX_CLUBS-1],
    output reg valid,
    output reg [3:0] assignment [0:MAX_CLUBS-1],
    output reg impossible
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CHECK = 3'd1;
localparam [2:0] INCREMENT = 3'd2;
localparam [2:0] VALID = 3'd3;
localparam [2:0] IMPOSSIBLE = 3'd4;

reg [2:0] state;
reg [3:0] indices [0:MAX_CLUBS-1];
reg [3:0] next_indices [0:MAX_CLUBS-1];
reg overflow_flag;
reg [3:0] resident_idx_temp [0:MAX_CLUBS-1];
reg is_valid_temp;
reg [3:0] threshold_temp;

integer i, j, p;
always @(*) begin
    // Defaults
    for (i = 0; i < MAX_CLUBS; i = i + 1) begin
        if (i < num_clubs) begin
            resident_idx_temp[i] = club_residents[i * MAX_RESIDENTS + indices[i]];
        end else begin
            resident_idx_temp[i] = 4'hF;
        end
    end
    
    reg is_distinct;
    reg [3:0] party_counts [0:MAX_PARTIES-1];
    
    // Initialize
    is_distinct = 1'b1;
    for (p = 0; p < MAX_PARTIES; p = p + 1) begin
        party_counts[p] = 4'd0;
    end
    
    // Check distinctness
    for (i = 0; i < num_clubs; i = i + 1) begin
        if (resident_idx_temp[i] >= num_residents) begin
            is_distinct = 1'b0;
        end
        for (j = i+1; j < num_clubs; j = j + 1) begin
            if (resident_idx_temp[i] == resident_idx_temp[j]) begin
                is_distinct = 1'b0;
            end
        end
    end
    
    // Count parties
    if (is_distinct) begin
        for (i = 0; i < num_clubs; i = i + 1) begin
            p = resident_party[resident_idx_temp[i]];
            if (p < num_parties) begin
                party_counts[p] = party_counts[p] + 4'd1;
            end
        end
    end
    
    // Compute threshold (ceil(num_clubs/2))
    threshold_temp = (num_clubs + 1) >> 1;
    
    // Final validity check
    is_valid_temp = is_distinct;
    for (p = 0; p < num_parties; p = p + 1) begin
        if (party_counts[p] >= threshold_temp) begin
            is_valid_temp = 1'b0;
        end
    end
end

// Next indices computation
always @(*) begin
    reg carry;
    carry = 1'b1;
    overflow_flag = 1'b0;
    
    for (i = 0; i < MAX_CLUBS; i = i + 1) begin
        next_indices[i] = indices[i];
        if (i < num_clubs && carry) begin
            next_indices[i] = indices[i] + 4'd1;
            if (next_indices[i] >= club_size[i]) begin
                next_indices[i] = 4'd0;
                carry = 1'b1;
            end else begin
                carry = 1'b0;
            end
        end
    end
    
    overflow_flag = carry;
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        valid <= 1'b0;
        impossible <= 1'b0;
        for (i = 0; i < MAX_CLUBS; i = i + 1) begin
            indices[i] <= 4'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CHECK;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    for (i = 0; i < MAX_CLUBS; i = i + 1) begin
                        indices[i] <= 4'd0;
                    end
                end
            end
            
            CHECK: begin
                if (is_valid_temp) begin
                    for (i = 0; i < MAX_CLUBS; i = i + 1) begin
                        assignment[i] <= resident_idx_temp[i];
                    end
                    valid <= 1'b1;
                    state <= VALID;
                end else begin
                    state <= INCREMENT;
                end
            end
            
            INCREMENT: begin
                if (overflow_flag) begin
                    impossible <= 1'b1;
                    state <= IMPOSSIBLE;
                end else begin
                    for (i = 0; i < MAX_CLUBS; i = i + 1) begin
                        indices[i] <= next_indices[i];
                    end
                    state <= CHECK;
                end
            end
            
            VALID: begin
                // Maintain state until reset
            end
            
            IMPOSSIBLE: begin
                // Maintain state until reset
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule