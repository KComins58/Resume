const filterButton = document.querySelector('#filter-button');
const keywordsInput = document.querySelector('#keywords');
const locationInput = document.querySelector('#location');
const featuredJobsContainer = document.querySelector('.featured-jobs');
let jobs = [];

// Fetch the JSON data and generate the elements for all jobs
fetch('jobs-data.json')
  .then(response => response.json())
  .then(data => {
    jobs = data;
    jobs.forEach(generateJobElement);
  });

function filterJobs() {
  const keywords = keywordsInput.value.trim().toLowerCase();
  const location = locationInput.value.trim().toLowerCase();

  // Clear the featured jobs container
  featuredJobsContainer.innerHTML = '';

  // Filter the jobs by keywords and location
  const filteredJobs = jobs.filter(job => {
    return (
      job.title.toLowerCase().includes(keywords) &&
      job.location.toLowerCase().includes(location)
    );
  });

  // Generate and append the elements for the filtered jobs
  filteredJobs.forEach(generateJobElement);
}

keywordsInput.addEventListener('input', filterJobs);
locationInput.addEventListener('input', filterJobs);

function generateJobElement(job) {
  // Create the elements for the job
  const jobElement = document.createElement('div');
  const titleElement = document.createElement('h3');
  const companyElement = document.createElement('p');
  const locationElement = document.createElement('p');
  const applyContainer = document.createElement('div');
  const applyButton = document.createElement('a');

  // Set the content and attributes of the elements
  titleElement.textContent = job.title;
  companyElement.textContent = job.company;
  locationElement.textContent = job.location;

  // Check if the apply_url is empty
  if (job.apply_url === '') {
    applyButton.textContent = 'N/A';
    applyButton.classList.add('disabled');
  } else {
    applyButton.textContent = 'Apply Now';
    applyButton.href = job.apply_url;
  }

  // Set the classes of the elements
  jobElement.classList.add('job');
  applyContainer.classList.add('apply-button-container');

  // Append the elements to the job element
  jobElement.appendChild(titleElement);
  jobElement.appendChild(companyElement);
  jobElement.appendChild(locationElement);
  applyContainer.appendChild(applyButton);
  jobElement.appendChild(applyContainer);

  // Append the job element to the featured jobs container
  featuredJobsContainer.appendChild(jobElement);
}
