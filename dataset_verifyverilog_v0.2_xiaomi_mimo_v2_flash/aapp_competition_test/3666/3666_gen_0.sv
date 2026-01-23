module gear_ratio_solver(
    input clk,
    input rst_n,
    input start,
    input [6:0] num_ratios,
    input [7:0] num_array [0:7],
    input [7:0] den_array [0:7],
    output reg [15:0] front1,
    output reg [15:0] front2,
    output reg [15:0] rear0,
    output reg [15:0] rear1,
    output reg [15:0] rear2,
    output reg [15:0] rear3,
    output reg [15:0] rear4,
    output reg [15:0] rear5,
    output reg done,
    output reg impossible
);

    // States
    localparam IDLE = 5'b00001;
    localparam PREPROCESS = 5'b00010;
    localparam SEARCH_FRONT = 5'b00100;
    localparam SEARCH_REAR = 5'b01000;
    localparam VERIFY = 5'b10000;

    reg [4:0] state;
    
    // Preprocessing Registers
    reg [7:0] ratio_num [0:11];
    reg [7:0] ratio_den [0:11];
    reg [3:0] num_count;
    reg [3:0] den_count;
    
    // Candidate Arrays
    reg [15:0] num_candidates [0:7];
    reg [15:0] den_candidates [0:7];
    
    // Search State Registers
    reg [2:0] num_idx1;
    reg [2:0] num_idx2;
    reg [2:0] den_idx0;
    reg [2:0] den_idx1;
    reg [2:0] den_idx2;
    reg [2:0] den_idx3;
    reg [2:0] den_idx4;
    reg [2:0] den_idx5;
    
    // Verification Loop
    reg [3:0] verify_idx;
    
    // Helper variables for computation
    reg [7:0] a_in, b_in;
    wire [7:0] gcd_out;
    reg gcd_start;
    wire gcd_done;
    
    // GCD Module (Iterative Euclidean)
    gcd_mod gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_start),
        .a(a_in),
        .b(b_in),
        .gcd(gcd_out),
        .done(gcd_done)
    );

    // Integer indices for loops
    integer i;
    integer j;
    reg found;
    reg mismatch;
    reg [15:0] r_num;
    reg [15:0] r_den;
    reg [15:0] calc_ratio;
    reg [15:0] calc_prod;

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            impossible <= 0;
            front1 <= 0;
            front2 <= 0;
            rear0 <= 0;
            rear1 <= 0;
            rear2 <= 0;
            rear3 <= 0;
            rear4 <= 0;
            rear5 <= 0;
            gcd_start <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    if (start) begin
                        state <= PREPROCESS;
                        num_count <= 0;
                        den_count <= 0;
                        gcd_start <= 0;
                        j <= 0; // used for indexing input array
                    end
                end

                PREPROCESS: begin
                    // Step 1: Reduce ratios
                    // We use a two-pass approach implicitly by iterating inputs
                    // Since we need to reduce inputs first, we iterate j from 0 to 7
                    if (j < 8) begin
                        if (num_array[j] != 0 && den_array[j] != 0) begin
                            a_in <= num_array[j];
                            b_in <= den_array[j];
                            gcd_start <= 1;
                            state <= PREPROCESS; // Stay here until GCD handled
                        end else begin
                            j <= j + 1;
                        end
                    end else begin
                        // Finished reducing all inputs, now collect unique
                        // Reset indices for collection
                        num_count <= 0;
                        den_count <= 0;
                        i <= 0;
                        state <= SEARCH_FRONT; // Advance to search setup
                    end
                    
                    // Handle GCD Handshake
                    if (gcd_start) begin
                        if (gcd_done) begin
                            gcd_start <= 0;
                            // Store reduced numerator
                            ratio_num[j] <= a_in / gcd_out;
                            // Store reduced denominator
                            ratio_den[j] <= b_in / gcd_out;
                            j <= j + 1;
                        end
                    end
                end

                SEARCH_FRONT: begin
                    // Collect unique numerators and denominators from ratio_num/ratio_den
                    // This part happens once before iterating pairs
                    if (i < 8) begin
                        // Check if we have this numerator already in num_candidates
                        found <= 0;
                        for (int k = 0; k < 8; k = k + 1) begin
                            if (k < num_count && num_candidates[k] == ratio_num[i]) found <= 1;
                        end
                        // If not found and valid, add it
                        if (!found && ratio_num[i] != 0 && num_count < 8) begin
                            num_candidates[num_count] <= ratio_num[i];
                            num_count <= num_count + 1;
                        end
                        // Check denominators
                        found <= 0;
                        for (int k = 0; k < 8; k = k + 1) begin
                            if (k < den_count && den_candidates[k] == ratio_den[i]) found <= 1;
                        end
                        if (!found && ratio_den[i] != 0 && den_count < 8) begin
                            den_candidates[den_count] <= ratio_den[i];
                            den_count <= den_count + 1;
                        end
                        i <= i + 1;
                    end else begin
                        // Done collecting, check if enough candidates
                        if (num_count >= 2 && den_count >= 6) begin
                            num_idx1 <= 0;
                            num_idx2 <= 1;
                            state <= SEARCH_REAR;
                        end else begin
                            impossible <= 1;
                            done <= 1;
                            state <= IDLE;
                        end
                    end
                end

                SEARCH_REAR: begin
                    // Assign rear sprockets using the first 6 unique denominators
                    // The prompt says: "try permutations of 6 distinct denominators... assume we take the 6 smallest"
                    // Since we want to find ANY solution, we will just pick the first 6 found
                    // which are stored in den_candidates[0:5]
                    // To ensure we don't just pick one permutation, let's slightly scramble if needed,
                    // but strictly speaking the hardware should search. 
                    // Given the constraints, let's iterate permutations of indices.
                    
                    // Simplification for search space:
                    // We will iterate through permutations of the 6 smallest denominators.
                    // Since we don't have a clock cycle to wait for permutation generation, 
                    // we will generate them dynamically.
                    
                    // Actually, for this assignment, let's implement a standard permutation counter
                    // on the indices den_idx0...den_idx5.
                    
                    rear0 <= den_candidates[den_idx0];
                    rear1 <= den_candidates[den_idx1];
                    rear2 <= den_candidates[den_idx2];
                    rear3 <= den_candidates[den_idx3];
                    rear4 <= den_candidates[den_idx4];
                    rear5 <= den_candidates[den_idx5];
                    
                    verify_idx <= 0;
                    state <= VERIFY;
                end

                VERIFY: begin
                    if (verify_idx < num_ratios) begin
                        r_num <= ratio_num[verify_idx];
                        r_den <= ratio_den[verify_idx];
                        
                        // Check if r_num matches front1 or front2
                        if (r_num == num_candidates[num_idx1]) begin
                            // Matched front1, check rears
                            // Look for denominator match in rear array
                            // Since rear array is unique (by assignment), we check equality
                            if (r_den == rear0 || r_den == rear1 || r_den == rear2 || 
                                r_den == rear3 || r_den == rear4 || r_den == rear5) begin
                                verify_idx <= verify_idx + 1;
                            end else begin
                                mismatch <= 1;
                            end
                        end else if (r_num == num_candidates[num_idx2]) begin
                            // Matched front2
                            if (r_den == rear0 || r_den == rear1 || r_den == rear2 || 
                                r_den == rear3 || r_den == rear4 || r_den == rear5) begin
                                verify_idx <= verify_idx + 1;
                            end else begin
                                mismatch <= 1;
                            end
                        end else begin
                            mismatch <= 1;
                        end
                    end else begin
                        // All ratios verified
                        front1 <= num_candidates[num_idx1];
                        front2 <= num_candidates[num_idx2];
                        done <= 1;
                        state <= IDLE;
                    end
                    
                    if (mismatch) begin
                        mismatch <= 0;
                        // Next permutation of rear indices
                        // To avoid combinatorial explosion in this simplified model, 
                        // we increment the last index. If it wraps, we increment the previous.
                        // This is a linear scan, not full permutation, but fits the 'iterative' state machine.
                        // Full permutation logic:
                        // Just cycling through combinations is usually enough for this specific '6 smallest' constraint
                        // where the user likely wants the exact 6.
                        // However, to be thorough as per 'permutations':
                        
                        if (den_idx5 < den_count - 1) den_idx5 <= den_idx5 + 1;
                        else begin
                            den_idx5 <= 0;
                            if (den_idx4 < den_count - 1) den_idx4 <= den_idx4 + 1;
                            else begin
                                den_idx4 <= 0;
                                if (den_idx3 < den_count - 1) den_idx3 <= den_idx3 + 1;
                                else begin
                                    den_idx3 <= 0;
                                    if (den_idx2 < den_count - 1) den_idx2 <= den_idx2 + 1;
                                    else begin
                                        den_idx2 <= 0;
                                        if (den_idx1 < den_count - 1) den_idx1 <= den_idx1 + 1;
                                        else begin
                                            den_idx1 <= 0;
                                            if (den_idx0 < den_count - 1) den_idx0 <= den_idx0 + 1;
                                            else begin
                                                // All rear permutations tried for this front pair
                                                den_idx0 <= 0;
                                                den_idx1 <= 1;
                                                den_idx2 <= 2;
                                                den_idx3 <= 3;
                                                den_idx4 <= 4;
                                                den_idx5 <= 5;
                                                
                                                // Next Front Pair
                                                if (num_idx2 < num_count - 1) begin
                                                    num_idx2 <= num_idx2 + 1;
                                                end else begin
                                                    num_idx2 <= num_idx1 + 2;
                                                    if (num_idx1 < num_count - 3) begin
                                                        num_idx1 <= num_idx1 + 1;
                                                    end else begin
                                                        // All pairs tried
                                                        impossible <= 1;
                                                        done <= 1;
                                                        state <= IDLE;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        state <= SEARCH_REAR;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

module gcd_mod(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] gcd,
    output reg done
);
    reg [7:0] x, y;
    reg working;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            working <= 0;
            gcd <= 0;
        end else begin
            if (start && !working) begin
                x <= a;
                y <= b;
                working <= 1;
                done <= 0;
            end else if (working) begin
                if (x == 0) begin
                    gcd <= y;
                    working <= 0;
                    done <= 1;
                end else if (y == 0) begin
                    gcd <= x;
                    working <= 0;
                    done <= 1;
                end else if (x > y) begin
                    x <= x - y;
                end else begin
                    y <= y - x;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule